# Safe Kafka
Hopefully reliable Kafka orchestration

## Requirements and assumptions
Both scripts are written against a particular kind of host. Apart from Docker daemon reachability, which `kup.sh` checks after its `apt-get` and clone steps but before starting any container and `kdown.sh` checks before stopping anything, and the `eth0` address, which `kup.sh` checks before doing anything else, none of the conditions below are checked up front, so a mismatch surfaces as a failure partway through a run rather than as a clear prerequisite error:
* a Debian-based host with `apt-get` and `sudo` — `kup.sh` installs `docker-compose` and `git` with `sudo apt-get install` and clones into `/opt` with `sudo git clone`
* `sudo` that does not prompt for a password, or an operator at the keyboard to enter it — the `apt-get install` calls pass `-y` so `apt-get` itself does not prompt, but `sudo` may still ask for a password in an unattended run
* a running Docker daemon reachable by the invoking user without `sudo` — every `docker` and `docker-compose` call in both scripts is unprivileged (typically `docker` group membership); `kup.sh` probes the daemon with `docker info` and exits non-zero before starting any container if it is not reachable, and `kdown.sh` runs the same probe and exits non-zero before running `docker-compose down`
* a `docker-compose` binary — both scripts call `docker-compose`, not the `docker compose` plugin; they find this project's containers with `docker-compose ps -q <service>` for the `zookeeper` and `kafka` services in `docker-compose.yml` rather than by container name, so neither the container naming scheme, which differs between Compose v1 and v2, nor the name of the checkout directory is hardcoded
* the scripts run from the repository root — `docker-compose` is invoked without `-f`, so `docker-compose.yml` is resolved relative to the current directory, and only containers belonging to the Compose project of that directory are found
* a network interface named `eth0` with an IPv4 address, unless `DOCKER_HOST_IP` is exported before running — both scripts otherwise read the address from `ip addr show eth0`, taking the first one; if no address is found, `kup.sh` exits non-zero before running `apt-get`, while `kdown.sh` prints a warning and continues with an empty `DOCKER_HOST_IP`, since `docker-compose down` does not use it
* Kafka is detected as running only through this project's `kafka` service — both scripts look up that service's container with `docker-compose ps -q kafka` and then check with `docker ps` that it is running, so other containers whose names contain `kafka`, including this project's own Zookeeper container, do not affect the result

## kup.sh
The `kup.sh` script prepares the host, starts Kafka, and then verifies that it came up.

The following setup steps are performed first:
* `DOCKER_HOST_IP` is derived from the first `eth0` IPv4 address if the variable is not already set; if `eth0` has no IPv4 address, the script exits with a non-zero exit code
* `apt-get update` is run and `docker-compose` is installed with `apt-get install -y`
* wurstmeister/kafka-docker is cloned to `/opt/local-wurstmeister-kafka-docker` if that directory does not exist, installing `git` first with `apt-get install -y`

If either `apt-get install` fails, the script reports which package could not be installed and exits with a non-zero exit code before any container is started. The same applies if the clone fails. A failed `apt-get update` is reported as a warning only, and the script continues with the existing package lists.

The following checks are then performed, in order:
* the `docker` command is available — note that this confirms the client is installed, not that the daemon is running
* the Docker daemon is reachable — `docker info` must succeed for the invoking user; if it does not, the script exits with a non-zero exit code before any container is started
* kafka is not already running — that is, the container `docker-compose ps -q kafka` reports for this project is not running; if it is, the script reports success and exits without starting anything
* `docker-compose up` succeeds — the script first runs `docker-compose down --remove-orphans` to clear any containers left over from a previous run (its result is not checked), then starts the services with `docker-compose up --remove-orphans --build -d`
* a container exists for each of the `zookeeper` and `kafka` services — each is looked up with `docker-compose ps -q`, and the failure reason names the service whose container could not be found
* zookeeper and kafka log counts are sufficient
* a topic can be created
* a topic can be deleted

If all checks pass, Kafka will have started successfully. If `docker-compose up` or any later check fails, the script tears the containers down with `docker-compose down --remove-orphans`, reports the reason for the failure, and exits with a non-zero exit code.

## kdown.sh
Before stopping anything, the `kdown.sh` script checks that the Docker daemon is reachable with `docker info`, exiting non-zero if it is not. It then shuts down Kafka/Zookeeper and removes the containers with `docker-compose down --remove-orphans`. It then looks up the `kafka` service's container with `docker-compose ps -q kafka` and confirms that it is no longer running, exiting non-zero if it is, or if `docker-compose ps` itself fails; other containers are not considered, so a Zookeeper container left running is not reported. Volumes are not removed. Before any of this, if `DOCKER_HOST_IP` is not already set, it is derived from the first `eth0` IPv4 address, as in `kup.sh`; unlike `kup.sh`, if `eth0` has no IPv4 address the script warns and continues with the variable empty rather than exiting, so that teardown is never refused.

## License
This project is licensed under the **Stephenson Software Non-Commercial License (Stephenson-NC)**.  
© 2025 Daniel McCoy Stephenson. All rights reserved.  

You may use, modify, and share this software for **non-commercial purposes only**.  
Commercial use is prohibited without explicit written permission from the copyright holder.  

Full license text: [Stephenson-NC License](https://github.com/Stephenson-Software/stephenson-nc-license)  
SPDX Identifier: `Stephenson-NC`
