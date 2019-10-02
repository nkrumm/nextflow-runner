#!/bin/bash

echo $AWS_ACCESS_KEY_ID
echo $BATCHMAN_LOG_ENDPOINT

aws s3 cp $1 .
aws s3 cp $2 .

nextflow run main.nf -config nextflow.config -with-weblog $BATCHMAN_LOG_ENDPOINT