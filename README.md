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
This project is licensed under the **Stephenson Software Non-Commercial License (Stephenson-NC)**.  
© 2025 Daniel McCoy Stephenson. All rights reserved.  

You may use, modify, and share this software for **non-commercial purposes only**.  
Commercial use is prohibited without explicit written permission from the copyright holder.  

Full license text: [Stephenson-NC License](https://github.com/Stephenson-Software/stephenson-nc-license)  
SPDX Identifier: `Stephenson-NC`
