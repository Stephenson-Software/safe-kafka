echo "Updating apt..."
sudo apt-get update

# prereqs
echo "Checking prerequisites..."
sudo apt-get install docker-compose
sudo apt-get install git
dir=/opt/my-kafka-docker
if [ ! -d  "$dir" ]; then
	echo "Cloning..."
	sudo git clone https://github.com/dmccoystephenson/my-kafka-docker /$dir
fi

# TODO: check if docker is installed

# spin up kafka
echo "Spinning up kafka..."
docker-compose down --remove-orphans
docker-compose up --remove-orphans --build -d

# show running containers
docker ps

# TODO: scale kafka up to 2-3 instances

# TODO: verify that zookeeper container is running and can be reached

# TODO: verify that kafka container is running and can be reached
sleep 2
kafkaLogCount=$(docker logs safe-kafka_kafka_1 | wc -l)
echo "Number of kafka logs: $kafkaLogCount"
if (( $kafkaLogCount < 10 )); then
	echo "Kafka container is probably not running."
fi

if (( $kafkaLogCount > 9 )); then
	echo "Kafka container is probably up!"
fi
