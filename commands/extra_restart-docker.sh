#!/usr/bin/bash

# save current directory
export CURRENT_DIR=$PWD;

# change directories
cd /opt/CVE-2022-24112-Lab/docker-files

# stop docker instance
docker-compose -p docker-apisix stop

# restart docker instance
docker-compose -p docker-apisix up -d

# return to previous directory
cd $CURRENT_DIR