#!/bin/bash
set -e  # fail on any error

echo "== Configuruation =="
echo $AWS_ACCESS_KEY_ID
echo $BATCHMAN_LOG_ENDPOINT
echo $NF_SESSION_CACHE_DIR_IN # this is passed in if a restart is desired
echo $NF_SESSION_CACHE_DIR_OUT # this is a new directory based on current ARN
echo $NEXTFLOW_OPTIONS

echo "== Downloading Script and Config =="
aws s3 cp $1 .
aws s3 cp $2 .

echo "== Restoring Session Cache =="
# stage in session cache
# .nextflow directory holds all session information for the current and past runs.
# We separately store .nextflow/ directories by the Fargate Task ARN, which means
# that restarts can be identified by the prior Task ARN.
# TODO: should this be the Task ARN or a more constant identifier?
# it should be `sync`'d with an s3 uri, so that runs from previous sessions can be 
# resumed
# taken from https://docs.opendata.aws/genomics-workflows/orchestration/nextflow/nextflow-overview/
aws s3 sync --only-show-errors $NF_SESSION_CACHE_DIR_IN/.nextflow .nextflow

function preserve_session() {
    # stage out session cache
    if [ -d .nextflow ]; then
        echo "== Preserving Session Cache =="
        aws s3 sync --only-show-errors .nextflow $NF_SESSION_CACHE_DIR_OUT/.nextflow
    fi
}

trap preserve_session EXIT

echo "== Start Nextflow =="
echo "nextflow run main.nf -config nextflow.config -with-weblog $BATCHMAN_LOG_ENDPOINT $NEXTFLOW_OPTIONS"
nextflow run main.nf -config nextflow.config -with-weblog $BATCHMAN_LOG_ENDPOINT $NEXTFLOW_OPTIONS