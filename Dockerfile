FROM ubuntu:14.04

RUN apt-get -y install apt-transport-https software-properties-common && \
    add-apt-repository -y ppa:james-page/docker && \
    add-apt-repository -y "deb https://clusterhq-archive.s3.amazonaws.com/ubuntu/$(lsb_release --release --short)/\$(ARCH) /" && \
    apt-get update && \
    apt-get -y --force-yes install clusterhq-flocker-node

ENTRYPOINT [ "/bin/bash" ]
