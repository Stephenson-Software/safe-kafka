#!/bin/bash

# colors
b='\e[0;30m'
w='\e[0;37m'
y='\e[0;33m'
r='\e[0;31m'
g='\e[0;32m'
nc='\e[0m'

if [[ $DOCKER_HOST_IP == "" ]]; then
	# get eth0 ip address from 'ip addr' command
	export DOCKER_HOST_IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
	echo -e "${y}DOCKER_HOST_IP not set. Setting to $DOCKER_HOST_IP${nc}"
fi

# if kafka is not running, exit
if [[ $(docker ps -f name=kafka -q) == "" ]]; then
    echo -e "${g}Kafka is not running.${nc}"
    exit 1
fi

echo -e "${y}Stopping kafka..."
docker-compose down --remove-orphans

# if kafka is not running, success
if [[ $(docker ps -f name=kafka -q) == "" ]]; then
    echo -e "${g}Kafka is stopped.${nc}"
    exit 0
else
    echo -e "${r}Kafka is still running.${nc}"
    exit 1
fi