#!/bin/bash
set -e  # fail on any error

echo "== Configuration =="
TASK_ARN=$(curl --silent ${ECS_CONTAINER_METADATA_URI}/task | jq -r '.TaskARN' | awk -F 'task/' '{print $2}')
WEBLOG_ENDPOINT="${API_ENDPOINT}/api/external/weblog?key=${LOGGING_API_KEY}&taskArn=${TASK_ARN}"

echo "AWS_ACCESS_KEY_ID = ${AWS_ACCESS_KEY_ID}"
echo "API_ENDPOINT      = ${API_ENDPOINT}"
echo "API_KEY           = ${API_KEY}"
echo "LOGGING_API_KEY   = ${LOGGING_API_KEY}"
echo "TASK_ARN          = ${TASK_ARN}"
echo "WEBLOG_ENDPOINT   = ${WEBLOG_ENDPOINT}"

if [ ! -z "$NF_SESSION_CACHE_ARN" ]; then
	NF_SESSION_CACHE_DIR_IN="${NF_SESSION_CACHE_DIR}/${NF_SESSION_CACHE_ARN}"
	echo "NF_SESSION_CACHE_ARN is set, will attempt -resume with cache from ${NF_SESSION_CACHE_DIR_IN}"
fi
# this needs to be set regardless, to save current workflow .nextflow/
NF_SESSION_CACHE_DIR_OUT="${NF_SESSION_CACHE_DIR}/${TASK_ARN}"
echo $NF_SESSION_CACHE_DIR_OUT # this is a new directory based on current ARN

echo $NEXTFLOW_OPTIONS

echo "== Downloading Script and Config =="
aws s3 cp $1 .
aws s3 cp $2 .

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
echo "nextflow run main.nf -config nextflow.config -with-weblog $WEBLOG_ENDPOINT $NEXTFLOW_OPTIONS"
# turn off ANSI logging for clarity
export NXF_ANSI_LOG=false
nextflow run main.nf -config nextflow.config  -with-weblog $WEBLOG_ENDPOINT $NEXTFLOW_OPTIONS
echo "== Done =="