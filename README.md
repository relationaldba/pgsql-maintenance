# pgsql-maintenance

Run PostgreSQL maintenance tasks like Vacuum + Analyze, Analyze only, Vacuum large objects and Reindex.

## Introduction

The project aims to provide a unified script that can perform all the standard PostgreSQL maintenance tasks. The script can be scheduled to run as a standalone shell script or in a docker container.

The script interprets the the first argument as the action.
The action argument can be one of the following:

- `pgsql-maintenance.sh vacuum_db` - run vacuum + analyze (does not run vacuum full)
- `pgsql-maintenance.sh analyze_db` - run analyze only
- `pgsql-maintenance.sh vacuum_lo` - run vacuum largeobjects
- `pgsql-maintenance.sh reindex_db` - run reindex concurrently on user tables
- `pgsql-maintenance.sh reindex_sys` - run reindex on system catalogs

## Environment Configuration:

The script uses the standard PostgreSQL environment variables. Refer https://www.postgresql.org/docs/current/libpq-envars.html for a list of supported environment variables.

The script expects the following commonly used PostgreSQL environment variables to establish connection to the PostgreSQL server:

- `PGHOST` - Name of host to connect to.
- `PGPORT` - Port number to connect to at the server host.
- `PGUSER` - User name to connect as.
- `PGPASSWORD` - Password to be used if the server demands password.
- `PGSSLMODE` - SSL mode to use to make the connection.

The script expects on the following non-standard environment variables to
get the database names to run maintenance on and number of commands to run in parallel:

- `PGDATABASES` - Comma separated list of database names.
- `PGJOBS` - Execute in parallel by running PGJOBS commands simultaneously.

## How to run in a docker environment

It's recommended to run this script in docker so you don't have to worry about the dependencies. The image is based off `postgresql:alpine` image and comes bundled with the necessary utilities like vacuumdb, vacuumlo and reindexdb. The entrypoint of the docker container is `ENTRYPOINT ["/bin/bash","pgsql-maintenance.sh"]` and it requires an action argument to determine the type of maintenance to run.

Follow the below steps to get up and running in minutes:

### Prerequisites

- On your linux host, ensure the below packages are installed:
  - [x] docker
  - [x] docker-compose
  - [x] cron
  - [x] git
- Clone the repo on the host
  ```shell
  cd ~
  git clone https://github.com/relationaldba/pgsql-maintenance.git
  cd pgsql-maintenance/
  ```
- Build the docker image using the below command.
  ```shell
  docker build --pull --rm -f "Dockerfile" -t pgsql-maintenance:latest "."
  ```
- Prepare a `.env` file in the pgsql-maintenance folder. You can edit the sample env file `.env.example` provided in the repo and add your own configurations. The file should be named `.env`

### Run using docker

- Ensure the pre-requisites are completed
- Run the script in docker using the below command. The env file is passed to docker container using the option `--env-file` and an action argument needs to be added at the end.
  ```shell
  docker run --rm --env-file ./.env --name <container_name> pgsql-maintenance:latest <action>
  ```
- The option `--rm` ensures that the docker container is deleted after the script completes execution.

#### Examples

- To run vacuum + analyze:
  ```shell
  docker run --rm --env-file ./.env --name pgsql-vacuumdb pgsql-maintenance:latest vacuum_db
  ```
- To run vacuum on large objects:
  ```shell
  docker run --rm --env-file ./.env --name pgsql-vacuumlo pgsql-maintenance:latest vacuum_lo
  ```
- To run reindex:
  ```shell
  docker run --rm --env-file ./.env --name pgsql-reindexdb pgsql-maintenance:latest reindex_db
  ```
- To run analyze only:
  ```shell
  docker run --rm --env-file ./.env --name pgsql-analyzedb pgsql-maintenance:latest analyze_db
  ```

### Run using docker-compose

- Ensure the pre-requisites are completed
- Prepare a `docker-compose.yaml` file and describe the services. You can use the sample `docker-compose.yaml` provided in the repo. The YAML file has a list of all services and their action arguments.
- The YAML file expects the env file in the same directory and is described in the `env_file:` section.
- The action argument is passed to the container using the `command:` element of the compose file.
- Run the script using `docker-compose` using the below command.
  ```shell
  docker compose up <service_name>; docker compose down <service_name>;
  ```
- The container is deleted when the script completes execution and then `docker compose down` executes.

#### Examples

- To run vacuum + analyze:
  ```shell
  docker compose up pgsql-vacuumdb; docker compose down pgsql-vacuumdb;
  ```
- To run vacuum on large objects:
  ```shell
  docker compose up pgsql-vacuumlo; docker compose down pgsql-vacuumlo;
  ```
- To run reindex:
  ```shell
  docker compose up pgsql-reindexdb; docker compose down pgsql-reindexdb;
  ```
- To run analyze only:
  ```shell
  docker compose up pgsql-analyzedb; docker compose down pgsql-analyzedb;
  ```

### Schedule using cron

The docker containers can be run on a schedule using cron.

#### Example

- To run vacuumdb using docker every Saturday night at 11:00 PM, edit the cron file by running `crontab -e` and add the below line to the file.

  ```shell
  00  23  *  *  6  cd /home/<user>/pgsql-maintenance && docker run --rm --env-file ./.env --name pgsql-vacuumdb pgsql-maintenance:latest vacuum_db
  ```

- To run vacuumdb using `docker compose` every Saturday night at 11:00 PM, edit the cron file by running `crontab -e` and add the below line to the file.

  ```shell
  00  23  *  *  6  cd /home/<user>/pgsql-maintenance && docker compose up pgsql-vacuumdb; docker compose down pgsql-vacuumdb;
  ```

## How to run in a shell environment

Follow the below steps to get up and running in minutes:

### Prerequisites

- On your linux host, ensure the below packages are installed:
  - [x] cron
  - [x] git
- Clone the repo on the host
  ```shell
  cd ~
  git clone https://github.com/relationaldba/pgsql-maintenance.git
  cd pgsql-maintenance/
  ```
- Make the `pgsql-maintenance.sh` executable
  ```shell
  chmod +x pgsql-maintenance.sh
  ```
- Prepare a `.env` file in the pgsql-maintenance folder. You can edit the sample env file `.env.example` provided in the repo and add your own configurations. The file should be named `.env`. Export the env variables using the below command
  ```shell
  export $(xargs < ./.env)
  ```

### Run the shell script

- Ensure the pre-requisites are completed
- Run the script using the below command.
  ```shell
  ./pgsql-maintenance.sh <action>
  ```

#### Examples

- To run vacuum + analyze:
  ```shell
  ./pgsql-maintenance.sh vacuum_db
  ```
- To run vacuum on large objects:
  ```shell
  ./pgsql-maintenance.sh vacuum_lo
  ```
- To run reindex:
  ```shell
  ./pgsql-maintenance.sh reindex_db
  ```
- To run analyze only:
  ```shell
  ./pgsql-maintenance.sh analyze_db
  ```

### Schedule using cron

The script can be run on a schedule using cron.

#### Example

- To run vacuumdb every Saturday night at 11:00 PM, edit the cron file by running `crontab -e` and add the below line to the file.

  ```shell
  00  23  *  *  6  cd /home/<user>/pgsql-maintenance && export $(xargs < ./.env) && ./pgsql-maintenance.sh vacuum_db
  ```
