#!/bin/bash

# yaes - yet another enumeration script
# v0.0.1
# author: d47zm3

config_path=~/.yaes.conf

# follow log filename pattern: ${target}.${protocol}.${port}.${tool}
logs_path="${HOME}/.yaes/logs/"

arg_number=${#}
mode=${1}

status_file="${logs_path}/${target}/.status"

red='\033[0;31m'
green='\033[0;32m'
no_color='\033[0m'

web_services=1
wp_found=1
#nmap_logs="${logs_path}/${target}/nmap"

no_udp=0
no_tcp=0

long_jobs_pids=( )

function check_status
{
  if [[ ! -e ${status_file} ]]
  then
    echo 0 > ${status_file}
    return 0
  fi

  if [[ -e ${status_file} ]]
  then
    grep -q 0 ${status_file}
    if [[ ${?} -eq 0 ]]
    then
      return 0
    else
      return 1
    fi 
  fi
}

function decho
{
  string=${1}
  echo -e "[$( date +'%H:%M:%S' )] ${string}"
}

function decho_red
{
  string=${1}
  echo -e  "${red}[$( date +'%H:%M:%S' )] ${string}${no_color}"
}

function decho_green
{
  string=${1}
  echo -e "${green}[$( date +'%H:%M:%S' )] ${string}${no_color}"
}

function echo_green
{
  string=${1}
  echo -e "${green}${string}${no_color}"
}

function cheatsheet
{
  if [[ -z ${target} ]]
  then
    target="10.10.10.1"
  fi

  echo_green "discover hosts in range"
  echo "netdiscover -i \$interface -r ${target}/24"
  echo ""

  echo_green "quick scan using unicornscan - might not work on some vpns, after color - ports to scan, a for all ports, m for mode, tcp default, U for udp"
  echo "unicornscan ${target}:1-4000 ${target}:a -m [tcp,U]"
  echo ""
    
}

function help
{
  if [ "${arg_number}" -eq 0 ]
  then
    decho "usage: ${0} [--help/-h] <hostname/ip>"
    decho "or... --enumerate - this will run standalone enumeration on linux box and print output"
    decho "or... --cheatsheet [target]- this will print cheatsheet with common tools/examples, add hostname to input target address/hostname"
    decho "missing parameters, hostname or filename with hostnames required" 
    exit 1
  fi

 if [[ "${mode}" == "--help"  ]] || [[ "${mode}" == "-h" ]]
  then
    decho "usage: ${0} [--help/-h] <hostname/ip>"
    decho "or... --enumerate - this will run standalone enumeration on linux box and print output"
    decho "or... --cheatsheet [target]- this will print cheatsheet with common tools/examples, add hostname to input target address/hostname"
    exit 0
  fi

  if [[ "${mode}" == "--cheatsheet"  ]]
  then
    cheatsheet
    exit 0
  fi

  target=${mode}
  decho_green "starting yaes..."
}

function check_dependencies
{
  decho "checking for required tools if they are present..."
  tools=( nmap nikto gobuster wpscan amap )
  for tool in ${tools[@]}
  do
    which ${tool} 1>/dev/null
    if [[ ${?} -eq 1 ]]
    then
      decho "${tool} not present, please install it or add to default path..."
      exit 1
    fi
  done
}


function load_config
{
  decho "loading config file from ${config_path}..."
  source ${config_path}
  decho "using interface ${iface}"
  logs_structure
}

function check_wp
{
  url=${1}
  decho "checking for presence of wordpress..."
  curl -s -I -k ${url}/wp-content/ | grep "HTTP\/" | grep -q "404"
  if [[ ${?} -eq 1 ]]
  then
    wp_found=1
  fi
  curl -s -I -k ${url}/wp-includes/ | grep "HTTP\/" | grep -q "404"
  if [[ ${?} -eq 1 ]]
  then
    wp_found=1
  fi
  curl -s -I -k ${url}/wp-admin/ | grep "HTTP\/" | grep -q "404"
  if [[ ${?} -eq 1 ]]
  then
    wp_found=1
  fi

  if [[ ${wp_found} -eq 1 ]]
  then
    decho_green "found possible wordpress instance, enumerating..."

    wpscan_logs="${logs_path}/${target}/wpscan"
    mkdir -p "${wpscan_logs}"

    wpscan --url ${url} --batch --no-banner --random-agent --enumerate u > ${wpscan_logs}/${target}.tcp.${port}.wpscan &
    long_jobs_pids+=(${!})
    decho "running wpscan on ${target}/${port} in background..."
  fi
}

function web_scanners
{
  target=${1}
  port=${2}

  nikto_logs="${logs_path}/${target}/nikto"
  mkdir -p "${nikto_logs}"

  gobuster_logs="${logs_path}/${target}/gobuster"
  mkdir -p "${gobuster_logs}"

  nikto -Plugins "robots" -port ${port} -host  ${target} &> ${nikto_logs}/${target}.tcp.${port}.nikto &
  long_jobs_pids+=(${!})
  decho "running nikto on ${target}/${port} in background..."

  if [[ ${port} -eq 80 ]]
  then
    gobuster -k -w ${gobuster_wordlist} -u http://${target}:${port}/ -r -t 40 &> ${gobuster_logs}/${target}.tcp.${port}.gobuster &
    long_jobs_pids+=(${!})
    decho "running gobuster on ${target}/${port} in background..."
    
    check_wp "http://${target}:${port}/"
  elif [[ ${port} -eq 443 ]]
  then
    gobuster -k -w ${gobuster_wordlist} -u https://${target}:${port}/ -r -t 40 &> ${gobuster_logs}/${target}.tcp.${port}.gobuster &
    long_jobs_pids+=(${!})
    decho "running gobuster on ${target}/${port} in background..."

    check_wp "https://${target}:${port}/"
  fi


}


function long_scans
{

  amap_logs="${logs_path}/${target}/amap"
  mkdir -p ${amap_logs}

  nmap_logs="${logs_path}/${target}/nmap"

  if [[ ${no_tcp} -eq 0 ]]
  then
    open_ports=( $( cat "${nmap_logs}/${target}.tcp.nmap.quick.log" | grep -v "Not shown" | grep open | grep -o "^[0-9]*" ) )

    delim=$','
    printf -v var "%s$delim" "${open_ports[@]}"
    t_ports="${var%$delim}"

    decho "running detailed nmap scan on tcp ports ${t_ports} in background..."
    nmap -e ${iface} -A -sV -sC -oX ${nmap_logs}/${target}.tcp.detailed.xml -oG ${nmap_logs}/${target}.tcp.detailed.nmap.grep -p ${t_ports} ${target} &> ${nmap_logs}/${target}.nmap.tcp.detailed.output.log &
    long_jobs_pids+=(${!})

    for port in ${open_ports[@]}
    do

      decho "checking application mapping..."
      amap -A ${target} ${port} | grep Protocol | sed 's/Protocol/protocol/g' > ${amap_logs}/${target}.tcp.${port}.amap.log
      while read mapping
      do
       decho_green "${mapping}"
      done < ${amap_logs}/${target}.tcp.${port}.amap.log
      
      if egrep -q "http|http-apache|ssl" ${amap_logs}/${target}.tcp.${port}.amap.log
      then
        decho "port ${port} seems like web service, starting web scanners..."
        web_services=1
        web_scanners ${target} ${port}
      fi

    done
  fi

  if [[ ${no_udp} -eq 0 ]]
  then
    open_ports=( $( cat "${nmap_logs}/${target}.udp.nmap.quick.log" | grep -v "Not shown" | grep open | grep -o "^[0-9]*" ) )

    delim=$','
    printf -v var "%s$delim" "${open_ports[@]}" 
    u_ports="${var%$delim}"

    decho "running detailed nmap scan on udp ports ${u_ports} in background..."
    nmap -e ${iface} -sU -A -sV -sC -oX ${nmap_logs}/${target}.udp.detailed.xml -oG ${nmap_logs}/${target}.udp.detailed.grep -p ${u_ports} ${target} &> ${nmap_logs}/${target}.nmap.udp.detailed.output.log &
    long_jobs_pids+=(${!})

    for port in ${open_ports[@]}
    do

      decho "checking application mapping..."
      amap -A ${target} ${port} | grep Protocol > ${amap_logs}/${target}.udp.${port}.amap.log
      while read mapping
      do
       decho_green "${mapping}"
      done < ${amap_logs}/${target}.udp.${port}.amap.log
      
    done
  fi

}

function initial_scan_nmap
{
  if check_status
  then
    decho_green "found state file, not running scan..."
    return 0
  fi
  nmap_logs="${logs_path}/${target}/nmap"
  mkdir -p "${nmap_logs}"

  decho "running quick tcp nmap scan for open ports..."
  nmap -T4 -F -e ${iface}  ${target} &> ${nmap_logs}/${target}.tcp.nmap.quick.log
  decho "nmap quick scan results for tcp..."
  tcp_ports_count=$( cat ${nmap_logs}/${target}.tcp.nmap.quick.log | grep -v "Not shown" | grep open | wc -l )
  if [[ ${tcp_ports_count} -ne 0 ]]
  then
    cat ${nmap_logs}/${target}.tcp.nmap.quick.log | grep -v "Not shown" | grep open | awk -v date="$(date +"%H:%M:%S")" ' { print "\033[32m[" date "] found open port " $1 " for service " $3  "\033[0m" } '
  else
    decho_red "no open tcp ports found!"
    no_tcp=1
  fi

  decho "running quick udp nmap scan for open ports..."
  nmap -T4 -F -sU -e ${iface} ${target} &> ${nmap_logs}/${target}.udp.nmap.quick.log
  decho "nmap quick scan results for udp..."
  udp_ports_count=$( cat ${nmap_logs}/${target}.udp.nmap.quick.log | grep -v "Not shown" | grep open | wc -l )
  if [[ ${udp_ports_count} -ne 0 ]]
  then
    cat ${nmap_logs}/${target}.udp.nmap.quick.log | grep -v "Not shown" |  grep open | awk -v date="$(date +"%H:%M:%S")" ' { print "\033[32m[" date "] found open port " $1 " for service " $3  "\033[0m" } '
  else
    decho_red "no open udp ports found!"
    no_udp=1
  fi

  decho "starting long scans in background..."
  long_scans
  
}

function logs_structure
{
  mkdir -p ${logs_path}
}

function display_report
{
  echo 1 > ${status_file}
  decho_green "report for ${target}..."
  if [[ ${no_tcp} -eq 0 ]]
  then
    decho_green "found open ports/services for tcp..."
    cat ${nmap_logs}/${target}.nmap.tcp.detailed.output.log
  fi

  if [[ ${no_udp} -eq 0 ]]
  then
    decho_green "found open ports/services for tcp..."
    cat ${nmap_logs}/${target}.nmap.udp.detailed.output.log
  fi

  if [[ ${web_services} -eq 1 ]]
  then
    for file in ${nikto_logs}/*
    do
      address=$( cat ${file} | grep "Target IP" | awk ' { print $NF } ' )
      port=$( cat ${file} | grep "Target Port" | awk ' { print $NF } ' )
      decho_green "found web server ${address}/${port} info/issues..."
      cat ${file} | tail -n +6
    done

    gobuster_results=$( ls ${gobuster_logs}/ | wc -l )
    found_dirs=( )
    if [[ ${gobuster_results} -eq 2 ]]
    then
      decho "found two web services, checking if directories are the same..."
      for file in ${gobuster_logs}/*
      do
        dirs=$( cat ${file} | grep -i "status:" | sort )
        found_dirs+=( "${dirs}" )
      done

      if [[ ${found_dirs[0]} == ${found_dirs[1]} ]]
      then
        decho_green "directories are equal of both services..."
        cat ${gobuster_logs}/* | sort | uniq
      else
        decho_green "directories are different!"
        for file in ${gobuster_logs}/*
        do
          address=$( cat ${file} | egrep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*:[0-9]*" )
          decho "directories for ${address}..."
          cat ${file} | egrep -i "status:" | sort 
        done
      fi
    else
      decho "listing directories..."
      for file in ${gobuster_logs}/*
        do
          address=$( cat ${file} | egrep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*:[0-9]*" )
          decho "directories for ${address}..."
          cat ${file} | egrep -i "status:" | sort 
        done
    fi

    if [[ ${wp_found} -eq 1 ]]
    then
      decho_green "wordpress instance enumeration..."
      cat ${wpscan_logs}/${target}.tcp.*.wpscan
    fi
  fi
}

function loop_jobs
{

  if check_status
  then
    return 0
  fi

  finished=0

  decho "waiting for long scans to finish..."

  while [[ finished -eq 0 ]]
  do
    all_done=1
    for job in ${long_jobs_pids[@]}
    do
      #decho "[debug] all_done is ${all_done} and finished is ${finished}"
      #decho "checking job ${job}..."
      if  ps -p ${job} > /dev/null 
      then
        decho "job ${job} still running... $( ps -p ${job} --no-headers | awk ' { print $NF } ' )"
        all_done=0
      fi
    done
    if [[ ${all_done} -eq 1 ]]
    then
      finished=1
    fi
    sleep 10
  done
}

### main

help
check_dependencies
load_config
initial_scan_nmap
loop_jobs
display_report
decho_green "yaes has finished!"
