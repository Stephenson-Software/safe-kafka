# Safe Kafka
Hopefully reliable Kafka orchestration

## kup.sh
The `kup.sh` script prepares the host, starts Kafka, and then verifies that it came up.

The following setup steps are applied first, each one only if it has not already been done:
* `DOCKER_HOST_IP` is derived from the `eth0` address if the variable is not already set
* `docker-compose` and `git` are installed with `apt-get`
* wurstmeister/kafka-docker is cloned to `/opt/local-wurstmeister-kafka-docker` if that directory does not exist

The following checks are then performed, in order:
* the `docker` command is available — note that this confirms the client is installed, not that the daemon is running
* kafka is not already running — if it is, the script reports success and exits without starting anything
* zookeeper and kafka log counts are sufficient
* a topic can be created
* a topic can be deleted

If all checks pass, Kafka will have started successfully. If a check fails after the containers have been brought up, the script tears them down with `docker-compose down --remove-orphans`, reports the reason for the failure, and exits with a non-zero exit code.

## kdown.sh
The `kdown.sh` script shuts down Kafka/Zookeeper and removes the containers with `docker-compose down --remove-orphans`. It then confirms that no kafka container is left running, exiting non-zero if one is. Volumes are not removed, and `DOCKER_HOST_IP` is derived the same way as in `kup.sh` so that `docker-compose.yml` resolves.

## License
This project is licensed under the **Stephenson Software Non-Commercial License (Stephenson-NC)**.  
© 2025 Daniel McCoy Stephenson. All rights reserved.  

You may use, modify, and share this software for **non-commercial purposes only**.  
Commercial use is prohibited without explicit written permission from the copyright holder.  

Full license text: [Stephenson-NC License](https://github.com/Stephenson-Software/stephenson-nc-license)  
SPDX Identifier: `Stephenson-NC`
