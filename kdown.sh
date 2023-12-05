#!/bin/bash

# **********************************************************************************
# *   Copyright 2023 Daniel McCoy Stephenson
# *
# *   Licensed under the Apache License, Version 2.0 (the "License");
# *   you may not use this file except in compliance with the License.
# *   You may obtain a copy of the License at
# *
# *       http://www.apache.org/licenses/LICENSE-2.0
# *
# *   Unless required by applicable law or agreed to in writing, software
# *   distributed under the License is distributed on an "AS IS" BASIS,
# *   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# *   See the License for the specific language governing permissions and
# *   limitations under the License.
# *********************************************************************************

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

echo -e "${y}Stopping kafka and removing containers...${nc}"
docker-compose down --remove-orphans

# if kafka is not running, success
if [[ $(docker ps -f name=kafka -q) == "" ]]; then
    echo -e "${g}Kafka is stopped.${nc}"
    exit 0
else
    echo -e "${r}Kafka is still running.${nc}"
    exit 1
fi