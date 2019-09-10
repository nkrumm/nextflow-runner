FROM nextflow/nextflow:19.07.0

MAINTAINER Nik Krumm <nkrumm@uw.edu>

# Add AWS S3 
# from https://github.com/mesosphere/aws-cli/blob/master/Dockerfile
RUN apk -v --update add \
        python \
        py-pip \
        && \
    pip install --upgrade awscli==1.16.235 && \
    apk -v --purge del py-pip && \
    rm /var/cache/apk/*

RUN apk add curl jq

ADD runner.sh /usr/local/bin/

RUN chmod 775 /usr/local/bin/runner.sh

CMD ["/usr/local/bin/runner.sh"]
