# Safe Kafka
Hopefully reliable Kafka orchestration

## Requirements and assumptions
Both scripts are written against a particular kind of host. None of the conditions below are checked up front, so a mismatch surfaces as a failure partway through a run rather than as a clear prerequisite error:
* a Debian-based host with `apt-get` and `sudo` — `kup.sh` installs `docker-compose` and `git` with `sudo apt-get install` and clones into `/opt` with `sudo git clone`
* an operator at the keyboard — the `apt-get install` calls are issued without `-y`, so they block on a confirmation prompt when they need to pull in packages (see #7)
* a running Docker daemon reachable by the invoking user without `sudo` — every `docker` and `docker-compose` call in both scripts is unprivileged (typically `docker` group membership), and the only up-front check, `docker --version`, confirms the client is installed rather than that the daemon is reachable (see #13)
* Docker Compose **v1**, invoked as `docker-compose` — both scripts call that binary, and `kup.sh` expects the containers to be named `safe-kafka_zookeeper_1` and `safe-kafka_kafka_1`, which is the v1 naming scheme; Compose v2 names them differently (see #4)
* the repository checked out into a directory named `safe-kafka`, with `COMPOSE_PROJECT_NAME` unset or set to `safe-kafka` — Compose derives the `safe-kafka` prefix of those container names from the directory containing `docker-compose.yml`, and the scripts hardcode that prefix (see #4)
* the scripts run from the repository root — `docker-compose` is invoked without `-f`, so `docker-compose.yml` is resolved relative to the current directory
* a network interface named `eth0`, unless `DOCKER_HOST_IP` is exported before running — both scripts otherwise read the address from `ip addr show eth0`
* an interactive terminal — `kup.sh` runs its topic checks with `docker exec -it`, which fails when no TTY is attached (see #5)
* no other running container whose name contains `kafka` — both scripts detect a running Kafka with `docker ps -f name=kafka`, which matches on any part of a container name (see #15)

## kup.sh
The `kup.sh` script prepares the host, starts Kafka, and then verifies that it came up.

The following setup steps are performed first:
* `DOCKER_HOST_IP` is derived from the `eth0` address if the variable is not already set
* `apt-get update` is run and `docker-compose` is installed
* wurstmeister/kafka-docker is cloned to `/opt/local-wurstmeister-kafka-docker` if that directory does not exist, installing `git` first

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
