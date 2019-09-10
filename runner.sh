#!/bin/bash

aws s3 cp $1 .
aws s3 cp $2 .

nextflow run main.nf -config nextflow.config