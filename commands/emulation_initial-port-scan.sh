#!/usr/bin/bash

# perform three-way handshake scan of port 80 to obtain HTTP headers and save all output
nmap -sT --open -p80 --script http-headers -oA http_scan 172.31.24.111