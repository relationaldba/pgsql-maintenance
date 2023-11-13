#!/bin/bash
################################################################################
#
# Script Name: PostgreSQL vacuum large objects
#
# Description: The script will run vacuumlo to delete orphan largeobjects in the
# PostgreSQL database(s).
#
################################################################################

# Redirect output to the log of pid(1) for docker based deployment #
# exec 1>>/proc/1/fd/1 2>/proc/1/fd/2

# Variable EXIT_CODE stores the outcome, 0 for success, else failure
EXIT_CODE=0
SCRIPT_NAME="[$(basename "$0" .sh)]"

# Declare functions
function err() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') ERROR $*" >&2;
}

function log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') INFO  $*" >&1;
}

function validate_config() {

    local return_code=0

    # verify if the PostgreSQL connection params are specified in the env variables/file
    if [[ -z $PGHOST || -z $PGUSER || -z $PGPASSWORD || -z $PGDATABASES ]]
    then
        return_code=1;
    fi

    return $return_code;
}

function vacuumlo_db() {

    local return_code=0
    local database=$1

    output=$(vacuumlo "$database" 2>&1)
    return_code=$?
    
    if [[ $return_code == 0 ]]
    then
        log "${SCRIPT_NAME}" "${output}"
    else
        err "${SCRIPT_NAME}" "${output}"
    fi

    return $return_code;
}

# Validate the config file
validate_config;
if [[ $? != 0 ]]
then
    err "${SCRIPT_NAME}" "Connection parameter(s) missing, ensure PGHOST, PGUSER, PGPASSWORD and PGDATABASES are set"
    err "${SCRIPT_NAME}" "Failed to validate the environment configurations, see logs above"
    EXIT_CODE=1
    exit $EXIT_CODE;
fi

# Log connection info
log "${SCRIPT_NAME}" "PGHOST=${PGHOST}"
log "${SCRIPT_NAME}" "PGPORT=${PGPORT}"
log "${SCRIPT_NAME}" "PGDATABASES=${PGDATABASES}"
log "${SCRIPT_NAME}" "PGJOBS=${PGJOBS}"


# Iterate over each database specified in PGUSERDATABASES
for database in ${PGDATABASES//,/ }
do
    # vacuum the database
    log "${SCRIPT_NAME}" "Started for database ${database}" 
    vacuumlo_db $database;
    if [[ $? != 0 ]]
    then
        EXIT_CODE=1
        err "${SCRIPT_NAME}" "Failed for database ${database}, see logs above"
    else
        log "${SCRIPT_NAME}" "Completed for database ${database}"
    fi
done

if [[ $EXIT_CODE == 0 ]]
then
    log "${SCRIPT_NAME}" "Exit code ${EXIT_CODE}"
else
    err "${SCRIPT_NAME}" "Exit code ${EXIT_CODE}"
fi
exit $EXIT_CODE
