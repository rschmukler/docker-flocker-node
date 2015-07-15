FROM ubuntu:14.04

# Flocker Agent
RUN apt-get -y install apt-transport-https software-properties-common && \
    add-apt-repository -y ppa:james-page/docker && \
    add-apt-repository -y "deb https://clusterhq-archive.s3.amazonaws.com/ubuntu/$(lsb_release --release --short)/\$(ARCH) /" && \
    apt-get update && \
    apt-get -y --force-yes install clusterhq-flocker-node 

# Flocker-Docker-Plugin
RUN apt-get -y install python-pip build-essential libssl-dev libffi-dev python-dev wget && \
    pip install git+https://github.com/clusterhq/flocker-docker-plugin.git

RUN mkdir /etc/flocker
RUN groupadd docker
ADD build/docker /usr/bin/docker
ADD start.sh /root/flocker-config/start.sh
ADD build/agents/base-agent.yml /root/flocker-config/base-agent.yml
ADD build/agents/aws-agent.yml /root/flocker-config/aws-agent.yml
ADD build/ca-certificates.crt /etc/ssl/certs/

EXPOSE 4523
EXPOSE 4524

VOLUME [ "/etc/flocker", "/flocker" ]

WORKDIR /root/flocker-config

CMD [ "/bin/bash", "-c", "/root/flocker-config/start.sh" ]
