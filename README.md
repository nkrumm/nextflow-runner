## Nextflow-runner

This docker image is used by Batchman to run the Nextflow "head" process on Fargate.

Note this is built off of 721970950229.dkr.ecr.us-west-2.amazonaws.com/nextflow:latest, which is a custom Nextflow build. See
https://github.com/nkrumm/nextflow/tree/add-ecs-support for latest nextflow build.

### Building

 1. Get AWS credentials via saml2aws.
 2. Log in to AWS ECR with `$(aws ecr get-login --no-include-email --region us-west-2)`
 3. `docker build -t 721970950229.dkr.ecr.us-west-2.amazonaws.com/nextflow-runner:latest .`
 4. `docker push 721970950229.dkr.ecr.us-west-2.amazonaws.com/nextflow-runner:latest`

 
