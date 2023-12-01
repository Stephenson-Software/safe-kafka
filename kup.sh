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
docker-compose up --remove-orphans --build
docker-compose scale kafka=3
