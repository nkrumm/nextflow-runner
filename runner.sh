#!/bin/bash

curl 169.254.170.2$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI > creds.json

cat creds.json

export AWS_ACCESS_KEY_ID=`jq -r .AccessKeyId creds.json`
export AWS_SECRET_ACCESS_KEY=`jq -r .SecretAccessKey creds.json`
export AWS_SESSION_TOKEN=`jq -r .Token creds.json`

rm creds.json

aws s3 cp $1 .
aws s3 cp $2 .

nextflow run main.nf -config nextflow.config