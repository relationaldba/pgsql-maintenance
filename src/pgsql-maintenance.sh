#!/bin/bash
################################################################################
#
# Script Name: PostgreSQL Maintenance Tasks
#
# Description: The script is an entrypoint to run the vacuum, vacuumlo and
# reindex jobs. The script interprets the the first argument as the action.
# The arguments can be one of the following:
#   pgsql-maintenance.sh vacuum_db      # run vacuum + analyze              # 
#   pgsql-maintenance.sh analyze_db     # run analyze only                  #
#   pgsql-maintenance.sh vacuum_lo      # run vacuum largeobjects           #
#   pgsql-maintenance.sh reindex_db     # run reindex on user tables        #
#   pgsql-maintenance.sh reindex_sys    # run reindex on system catalogs    #
#
# The PostgreSQL environment variables are used for connection parameters
# refer https://www.postgresql.org/docs/current/libpq-envars.html for details
#
# The following standard PostgreSQL environment variables are used by the script
# to establish connection to the PostgreSQL server
#
#   PGHOST - Name of host to connect to.
#   PGPORT - Port number to connect to at the server host.
#   PGUSER - PostgreSQL user name to connect as.
#   PGPASSWORD - Password to be used if the server demands password.
#   PGSSLMODE - SSL mode to use to make the connection.
#
# The following non-standard environment variables are used by the script to 
# get the database names to run maintenance on and parallel commands
#
#   PGDATABASES - Comma separated list of database names.
#   PGJOBS - Execute in parallel by running PGJOBS commands simultaneously.
#
################################################################################

# Get the action argument
ACTION=$1;

# Start recording the elapsed seconds using the bash's internal counter
SECONDS=0;

# Variable EXIT_CODE stores the outcome, 0 for success, else failure
EXIT_CODE=0;

# Declare functions
function err() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') ERROR [${ACTION}] $*" >&2;
}

function log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') INFO  [${ACTION}] $*" >&1;
}

function end() {
    log "Completed in $(( $SECONDS / 3600 ))h $(( $SECONDS % 3600 / 60 ))m $(( $SECONDS % 60 ))s";
    exit $1;
}

function validate_config() {

    local return_code=0;

    # Verify if the PostgreSQL connection params are specified in the env variables/file
    if [[ -z $PGHOST || -z $PGUSER || -z $PGPASSWORD ]]
    then
        err "Connection parameter(s) invalid or missing";
        err "Verify the environment variables PGHOST, PGUSER and PGPASSWORD";
        return_code=1;
        return $return_code;
    fi

    # If the requested action does not match the expected value, exit with an error
    if [[ ${ACTION} != "vacuum_db" ]] \
        && [[ ${ACTION} != "analyze_db" ]] \
        && [[ ${ACTION} != "vacuum_lo" ]]  \
        && [[ ${ACTION} != "reindex_db" ]] \
        && [[ ${ACTION} != "reindex_sys" ]]
    then
        err "Invalid/missing argument";
        err "Usage:";
        err "pgsql-maintenance.sh vacuum_db      # run vacuum + analyze              #";
        err "pgsql-maintenance.sh analyze_db     # run analyze only                  #";
        err "pgsql-maintenance.sh vacuum_lo      # run vacuum largeobjects           #";
        err "pgsql-maintenance.sh reindex_db     # run reindex on user tables        #";
        err "pgsql-maintenance.sh reindex_sys    # run reindex on system catalogs    #";
        return_code=1;
        return $return_code;
    fi

    # If $PGDATABASES is not provided then get the list of all user databases
    if [[ -z $PGDATABASES ]]
    then
        PGDATABASES=$( psql \
            --dbname="postgres" \
            --command="SELECT string_agg(datname,',') FROM pg_database WHERE datdba> 10 and datistemplate = false;" \
            --tuples-only \
            --no-align );

        if (( $? != 0 ))
        then
            err "Failed to get the list of databases.";
            return_code=1;
            return $return_code;
        fi
    fi

    return $return_code;
}

function reindex_db() {

    local return_code=1;
    local database=$1;

    output=$(reindexdb --dbname="${database}" --jobs=$PGJOBS --concurrently 2>&1);
    return_code=$?;

    (( $return_code == 0 )) && log "${output}" || err "${output}";

    return $return_code;
}

function reindex_sys() {

    local return_code=1;
    local database=$1;

    output=$(reindexdb --dbname="${database}" --system 2>&1);
    return_code=$?;

    (( $return_code == 0 )) && log "${output}" || err "${output}";

    return $return_code;
}

function vacuum_db() {

    local return_code=1;
    local database=$1;

    output=$(vacuumdb --dbname="${database}" --analyze --jobs=$PGJOBS 2>&1);
    # TODO: add --force-index-cleanup
    # TODO: add --parallel=parallel_workers
    return_code=$?;

    (( $return_code == 0 )) && log "${output}" || err "${output}";

    return $return_code;
}

function analyze_db() {

    local return_code=1;
    local database=$1;

    output=$(vacuumdb --dbname="${database}" --analyze-only --analyze-in-stages --jobs=$PGJOBS 2>&1);
    # TODO: add --parallel=parallel_workers
    return_code=$?;

    (( $return_code == 0 )) && log "${output}" || err "${output}";

    return $return_code;
}

function vacuum_lo() {

    local return_code=1;
    local database=$1;

    output=$(vacuumlo "${database}" 2>&1);
    return_code=$?;

    (( $return_code == 0 )) && log "${output}" || err "${output}";

    return $return_code;
}

# Validate the configuration 
validate_config;
(( $? != 0 )) && EXIT_CODE=1 && end $EXIT_CODE;

# Log connection info
log "PGHOST=${PGHOST}";
log "PGPORT=${PGPORT}";
log "PGDATABASES=${PGDATABASES}";
log "PGJOBS=${PGJOBS}";

# Iterate over each database specified in PGDATABASES
for database in ${PGDATABASES//,/ }
do
    log "Started for database ${database}";

    # Run the maintenance action against the database
    $ACTION $database;

    if (( $? == 0 ))
    then
        log "Completed for database ${database}";
    else
        EXIT_CODE=1;
        err "Failed for database ${database}, see logs above";
    fi

done

(( $EXIT_CODE == 0 )) && log "Exit code ${EXIT_CODE}" || err "Exit code ${EXIT_CODE}";
end $EXIT_CODE
