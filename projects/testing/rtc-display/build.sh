#!/bin/bash
PATH=$PATH:$(pwd)/../../../tools
time mk65.sh src bin AUTOEXEC.BIN
read -n 1 -s -r -p "Press any key to continue"
exit
