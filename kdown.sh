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
y='\e[0;33m'
r='\e[0;31m'
g='\e[0;32m'
nc='\e[0m'

# service name from docker-compose.yml - the container is found through this rather than by container name
KAFKA_SERVICE_NAME="kafka"
NETWORK_CARD_INTERFACE="eth0"

# Prints the ID of the running container docker-compose created for service $1, or nothing if it is not running.
# Returns non-zero if docker-compose ps itself fails.
# Looking the container up through docker-compose works whatever the Compose version's naming scheme
# and whatever the checkout directory is called.
running_container_id_for_service() {
	local containerId
	containerId=$(docker-compose ps -q "$1") || return 1
	containerId=${containerId%%$'\n'*}
	if [[ $containerId == "" ]]; then
		return 0
	fi
	docker ps -q -f "id=$containerId"
}

if [[ $DOCKER_HOST_IP == "" ]]; then
	# get the network card interface's ip address from 'ip addr' command
	# take only the first address in case the interface has more than one
	export DOCKER_HOST_IP=$(ip addr show "$NETWORK_CARD_INTERFACE" | grep "inet\b" | awk '{print $2}' | cut -d/ -f1 | head -n1)
	if [[ $DOCKER_HOST_IP == "" ]]; then
		# docker-compose down does not need the address, so warn rather than refuse to tear down
		echo -e "${y}Could not derive DOCKER_HOST_IP: no IPv4 address found on network interface '$NETWORK_CARD_INTERFACE'. Continuing with it empty, since stopping the containers does not use it.${nc}"
	else
		echo -e "${y}DOCKER_HOST_IP not set. Setting to $DOCKER_HOST_IP${nc}"
	fi
fi

# check that the docker daemon is reachable by the invoking user
if ! docker info >/dev/null 2>&1; then
	echo -e "${r}Docker daemon not reachable. Is it running, and can this user access it without sudo?${nc}"
	exit 1
fi

echo -e "${y}Stopping kafka and removing containers...${nc}"
docker-compose down --remove-orphans

# look up this project's kafka service container - a failed lookup is not treated as "stopped"
if ! kafkaContainerId=$(running_container_id_for_service "$KAFKA_SERVICE_NAME"); then
	echo -e "${r}Could not check whether kafka is still running: docker-compose ps failed. Is the script being run from the repository root?${nc}"
	exit 1
fi

# if kafka is not running, success
if [[ $kafkaContainerId == "" ]]; then
    echo -e "${g}Kafka is stopped.${nc}"
    exit 0
else
    echo -e "${r}Kafka is still running.${nc}"
    exit 1
fi