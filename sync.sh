#!/bin/bash

# sync this repo to kali machine

rsync -avzh --exclude '.git' $(pwd)/ root@kali:~/security-git/
