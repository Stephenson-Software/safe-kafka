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

EXPECTED_ZOOKEEPER_CONTAINER_NAME="safe-kafka_zookeeper_1"
ZOOKEEPER_THRESHOLD=10

EXPECTED_KAFKA_CONTAINER_NAME="safe-kafka_kafka_1"
KAFKA_THRESHOLD=100

TIME_TO_WAIT_FOR_KAFKA_TO_START=30
NETWORK_CARD_INTERFACE="eth0"

TEST_TOPIC_NAME="test"

# This function is used to clean up and exit if kafka fails to start.
# $REASON_FOR_FAILURE is the reason why kafka failed to start.
throw_error() {
	echo -e ${r}=== ERROR ===${nc}
	docker-compose down --remove-orphans
	echo -e "${r}Kafka failed to start. Reason: '$REASON_FOR_FAILURE'${nc}"
	unset REASON_FOR_FAILURE
	exit 1
}

if [[ $DOCKER_HOST_IP == "" ]]; then
	# get eth0 ip address from 'ip addr' command
	export DOCKER_HOST_IP=$(ip addr show $NETWORK_CARD_INTERFACE | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
	echo -e "${y}DOCKER_HOST_IP not set. Setting to $DOCKER_HOST_IP${nc}"
fi

echo -e "${y}Updating apt...${nc}"
sudo apt-get update

# prereqs
echo -e "${y}Checking prerequisites...${nc}"
sudo apt-get install docker-compose

dir=/opt/local-wurstmeister-kafka-docker
if [ ! -d  "$dir" ]; then
	echo -e "${y}Cloning local-wurstmeister-kafka-docker...${nc}"
	sudo apt-get install git
	sudo git clone https://github.com/wurstmeister/kafka-docker /$dir
fi

# TODO: check if docker is running
dockerVersion=$(docker --version)
if [[ $dockerVersion == "" ]]; then
	echo -e "${r}Docker is not running.${nc}"
	exit 1
fi

# check if kafka is already running
if [[ $(docker ps -f name=kafka -q) != "" ]]; then
	echo -e "${g}Kafka is already running.${nc}"
	exit 0
fi

# spin up kafka
echo "Spinning up kafka..."
docker-compose down --remove-orphans
docker-compose up --remove-orphans --build -d

# show running containers
docker ps

zookeeperLogCountSufficient=false
kafkaLogCountSufficient=false

# wait for kafka to start
for i in $(seq 1 $TIME_TO_WAIT_FOR_KAFKA_TO_START); do
	secondsLeft=$((TIME_TO_WAIT_FOR_KAFKA_TO_START - $i))

	# verify that zookeeper/kafka containers have enough logs, otherwise throw error if time runs out
	zookeeperLogs=$(docker logs $EXPECTED_ZOOKEEPER_CONTAINER_NAME | wc -l)
	if [[ $zookeeperLogs -lt $ZOOKEEPER_THRESHOLD ]]; then
		if [[ $secondsLeft -eq 0 ]]; then
			REASON_FOR_FAILURE="zookeeper log count is $zookeeperLogs, less than threshold of $ZOOKEEPER_THRESHOLD"
			throw_error
		fi
	else
		zookeeperLogCountSufficient=true
	fi

	kafkaLogs=$(docker logs $EXPECTED_KAFKA_CONTAINER_NAME | wc -l)
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
docker exec -it $EXPECTED_KAFKA_CONTAINER_NAME /opt/kafka/bin/kafka-topics.sh --create --zookeeper zookeeper:2181 --replication-factor 1 --partitions 1 --topic $TEST_TOPIC_NAME
if [ $? -ne 0 ]; then
	echo -e "${r}Topic creation failed. Cleaning up."
	docker-compose down --remove-orphans
	REASON_FOR_FAILURE="topic creation failed"
	throw_error
fi

# verify that a topic can be deleted
echo -e "${y}Deleting topic...${nc}"
docker exec -it $EXPECTED_KAFKA_CONTAINER_NAME /opt/kafka/bin/kafka-topics.sh --delete --zookeeper zookeeper:2181 --topic $TEST_TOPIC_NAME
if [ $? -ne 0 ]; then
	REASON_FOR_FAILURE="topic deletion failed"
	throw_error
fi

echo -e "${g}Kafka started successfully!${nc}"