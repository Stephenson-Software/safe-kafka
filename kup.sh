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

# service names from docker-compose.yml - containers are found through these rather than by container name
ZOOKEEPER_SERVICE_NAME="zookeeper"
ZOOKEEPER_THRESHOLD=10

KAFKA_SERVICE_NAME="kafka"
KAFKA_THRESHOLD=100

TIME_TO_WAIT_FOR_KAFKA_TO_START=30
NETWORK_CARD_INTERFACE="eth0"

TEST_TOPIC_NAME="test"

# This function is used to clean up and exit if kafka fails to start.
# $REASON_FOR_FAILURE is the reason why kafka failed to start.
throw_error() {
	echo -e "${r}=== ERROR ===${nc}"
	docker-compose down --remove-orphans
	echo -e "${r}Kafka failed to start. Reason: '$REASON_FOR_FAILURE'${nc}"
	unset REASON_FOR_FAILURE
	exit 1
}

# Prints the ID of the container docker-compose created for service $1, running or not, or nothing if there is none.
# Returns non-zero if docker-compose ps itself fails.
# Looking the container up through docker-compose works whatever the Compose version's naming scheme
# and whatever the checkout directory is called.
container_id_for_service() {
	local containerIds
	containerIds=$(docker-compose ps -q "$1") || return 1
	echo "${containerIds%%$'\n'*}"
}

# Prints the ID of the running container docker-compose created for service $1, or nothing if it is not running.
# Returns non-zero if docker-compose ps itself fails.
running_container_id_for_service() {
	local containerId
	containerId=$(container_id_for_service "$1") || return 1
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
		echo -e "${r}Could not derive DOCKER_HOST_IP: no IPv4 address found on network interface '$NETWORK_CARD_INTERFACE'. Export DOCKER_HOST_IP, or set NETWORK_CARD_INTERFACE in kup.sh to an interface that has one.${nc}"
		exit 1
	fi
	echo -e "${y}DOCKER_HOST_IP not set. Setting to $DOCKER_HOST_IP${nc}"
fi

echo -e "${y}Updating apt...${nc}"
if ! sudo apt-get update; then
	echo -e "${y}apt-get update failed. Continuing with the existing package lists; check the apt-get output above.${nc}"
fi

# prereqs
echo -e "${y}Checking prerequisites...${nc}"
if ! sudo apt-get install -y docker-compose; then
	echo -e "${r}Failed to install docker-compose with apt-get. Check the apt-get output above.${nc}"
	exit 1
fi

dir=/opt/local-wurstmeister-kafka-docker
if [ ! -d  "$dir" ]; then
	echo -e "${y}Cloning local-wurstmeister-kafka-docker...${nc}"
	if ! sudo apt-get install -y git; then
		echo -e "${r}Failed to install git with apt-get. Check the apt-get output above.${nc}"
		exit 1
	fi
	if ! sudo git clone https://github.com/wurstmeister/kafka-docker "$dir"; then
		echo -e "${r}Failed to clone wurstmeister/kafka-docker into $dir. Check the git output above.${nc}"
		exit 1
	fi
fi

# check that the docker client is installed - this does not confirm the daemon is running
dockerVersion=$(docker --version)
if [[ $dockerVersion == "" ]]; then
	echo -e "${r}Docker client not found. Is docker installed and on PATH?${nc}"
	exit 1
fi

# check that the docker daemon is reachable by the invoking user
if ! docker info >/dev/null 2>&1; then
	echo -e "${r}Docker daemon not reachable. Is it running, and can this user access it without sudo?${nc}"
	exit 1
fi

# check if kafka is already running - only this project's kafka service container is considered
if [[ $(running_container_id_for_service "$KAFKA_SERVICE_NAME") != "" ]]; then
	echo -e "${g}Kafka is already running.${nc}"
	exit 0
fi

# spin up kafka
echo -e "${y}Spinning up kafka...${nc}"
docker-compose down --remove-orphans
if ! docker-compose up --remove-orphans --build -d; then
	REASON_FOR_FAILURE="docker-compose up failed"
	throw_error
fi

# show running containers
docker ps

# find the containers docker-compose created, failing with a specific reason if either is missing
zookeeperContainerId=$(container_id_for_service "$ZOOKEEPER_SERVICE_NAME")
if [[ $zookeeperContainerId == "" ]]; then
	REASON_FOR_FAILURE="no container found for the '$ZOOKEEPER_SERVICE_NAME' service after docker-compose up"
	throw_error
fi

kafkaContainerId=$(container_id_for_service "$KAFKA_SERVICE_NAME")
if [[ $kafkaContainerId == "" ]]; then
	REASON_FOR_FAILURE="no container found for the '$KAFKA_SERVICE_NAME' service after docker-compose up"
	throw_error
fi

zookeeperLogCountSufficient=false
kafkaLogCountSufficient=false

# wait for kafka to start
for i in $(seq 1 "$TIME_TO_WAIT_FOR_KAFKA_TO_START"); do
	secondsLeft=$((TIME_TO_WAIT_FOR_KAFKA_TO_START - i))

	# verify that zookeeper/kafka containers have enough logs, otherwise throw error if time runs out
	zookeeperLogs=$(docker logs "$zookeeperContainerId" | wc -l)
	if [[ $zookeeperLogs -lt $ZOOKEEPER_THRESHOLD ]]; then
		if [[ $secondsLeft -eq 0 ]]; then
			REASON_FOR_FAILURE="zookeeper log count is $zookeeperLogs, less than threshold of $ZOOKEEPER_THRESHOLD"
			throw_error
		fi
	else
		zookeeperLogCountSufficient=true
	fi

	kafkaLogs=$(docker logs "$kafkaContainerId" | wc -l)
	if [[ $kafkaLogs -lt $KAFKA_THRESHOLD ]]; then
		if [[ $secondsLeft -eq 0 ]]; then
			REASON_FOR_FAILURE="kafka log count is $kafkaLogs, less than threshold of $KAFKA_THRESHOLD"
			throw_error
		fi
	else
		kafkaLogCountSufficient=true
	fi

	if [[ $zookeeperLogCountSufficient == true && $kafkaLogCountSufficient == true ]]; then
		echo -e "${y}Zookeeper and kafka log counts are sufficient.${nc}"
		break
	fi
	
	echo -e "${y}Waiting $secondsLeft seconds for kafka to start...${nc}"
	sleep 1
done

# verify that a topic can be created
echo -e "${y}Creating topic...${nc}"
if ! docker exec "$kafkaContainerId" /opt/kafka/bin/kafka-topics.sh --create --zookeeper zookeeper:2181 --replication-factor 1 --partitions 1 --topic "$TEST_TOPIC_NAME"; then
	echo -e "${r}Topic creation failed. Cleaning up.${nc}"
	REASON_FOR_FAILURE="topic creation failed"
	throw_error
fi

# verify that a topic can be deleted
echo -e "${y}Deleting topic...${nc}"
if ! docker exec "$kafkaContainerId" /opt/kafka/bin/kafka-topics.sh --delete --zookeeper zookeeper:2181 --topic "$TEST_TOPIC_NAME"; then
	REASON_FOR_FAILURE="topic deletion failed"
	throw_error
fi

echo -e "${g}Kafka started successfully!${nc}"