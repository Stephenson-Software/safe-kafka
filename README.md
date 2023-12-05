# Safe Kafka
Hopefully reliable Kafka orchestration

## kup.sh
The `kup.sh` script performs the following checks:
* DOCKER_HOST_IP is set
* docker-compose is installed
* wurstmeister/kafka-docker is cloned to /opt/local-wurstmeister-kafka-docker
* docker is running
* kafka is not already running
* zookeeper and kafka log counts are sufficient
* a topic can be created
* a topic can be deleted

If all checks pass, Kafka will have started successfully. If any check fails, the script will exit with a non-zero exit code and clean up after itself.

## kdown.sh
The `kdown.sh` script shuts down Kafka/Zookeeper and removes all necessary containers and volumes.

## License
[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)