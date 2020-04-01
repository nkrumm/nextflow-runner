#!/bin/bash
set -e  # fail on any error

echo "== Configuration =="
TASK_ARN=$(curl --silent ${ECS_CONTAINER_METADATA_URI}/task | jq -r '.TaskARN' | awk -F 'task/' '{print $2}')
WEBLOG_ENDPOINT="${API_ENDPOINT}/api/v1/weblog?taskArn=${TASK_ARN}"

echo "EXECUTION_TYPE    = ${EXECUTION_TYPE}"
echo "API_ENDPOINT      = ${API_ENDPOINT}"
echo "API_KEY           = ${API_KEY}"
echo "TASK_ARN          = ${TASK_ARN}"
echo "WEBLOG_ENDPOINT   = ${WEBLOG_ENDPOINT}"
echo "NEXTFLOW_OPTIONS  = ${NEXTFLOW_OPTIONS}"

if [ ! -z "$NF_SESSION_CACHE_ARN" ]; then
   NF_SESSION_CACHE_DIR_IN="${NF_SESSION_CACHE_DIR}/${NF_SESSION_CACHE_ARN}"
   echo "NF_SESSION_CACHE_ARN is set, will attempt -resume with cache from ${NF_SESSION_CACHE_DIR_IN}"
fi
# this needs to be set regardless, to save current workflow .nextflow/
NF_SESSION_CACHE_DIR_OUT="${NF_SESSION_CACHE_DIR}/${TASK_ARN}"
echo $NF_SESSION_CACHE_DIR_OUT # this is a new directory based on current ARN

# stage in session cache
# .nextflow directory holds all session information for the current and past runs.
# We separately store .nextflow/ directories by the Fargate Task ARN, which means
# that restarts can be identified by the prior Task ARN.
# it should be `sync`'d with an s3 uri, so that runs from previous sessions can be 
# resumed
# taken from https://docs.opendata.aws/genomics-workflows/orchestration/nextflow/nextflow-overview/
if [ ! -z "$NF_SESSION_CACHE_DIR_IN" ]; then
    echo "== Restoring Session Cache =="
    aws s3 sync --only-show-errors $NF_SESSION_CACHE_DIR_IN/.nextflow .nextflow
fi


# Stage nextflow files or repository
case $EXECUTION_TYPE in 
    FILES)
        echo "== Downloading Script and Config =="
        aws s3 cp $1 .
        aws s3 cp $2 .
        NF_CMD="nextflow run main.nf -config nextflow.config"
        ;;
    
    GIT_URL)
        echo "== Running from Git Repository =="
        nextflow pull $1
        NF_CMD="nextflow run $1"
        ;;

    S3_URL)
        echo "== Downloading S3 Directory =="
        aws s3 sync $1 .
        NF_CMD="..." # TODO
        ;;

    *)
        echo "!! ERROR: Unknown execution type"
        exit 1
        ;;
esac


# if provided, download a params.json file which will override params in the config.
if [ ! -z "$NF_PARAMS_FILE" ]; then
    echo "== Downloading nextflow params file =="
    aws s3 cp $NF_PARAMS_FILE .
fi

function preserve_session() {
    # stage out session cache
    if [ -d .nextflow ]; then
        echo "== SIGTERM received =="
        echo "== Preserving Session Cache =="
        aws s3 sync --only-show-errors .nextflow $NF_SESSION_CACHE_DIR_OUT/.nextflow
        echo "== Done =="
    fi
}

trap preserve_session EXIT

echo "== Start Nextflow =="
echo "$NF_CMD -with-weblog $WEBLOG_ENDPOINT $NEXTFLOW_OPTIONS"
# turn off ANSI logging for clarity
export NXF_ANSI_LOG=false
$NF_CMD -with-weblog $WEBLOG_ENDPOINT $NEXTFLOW_OPTIONS
echo "== Done =="