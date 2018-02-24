port=135
target=arctic
nmap -p${port} --script smb-vuln-ms08-067.nse ${target}
nmap -p${port} --script smb-vuln-ms17-010 ${target}
