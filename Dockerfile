FROM ubuntu:14.04

RUN apt-get -y install apt-transport-https software-properties-common && \
    add-apt-repository -y ppa:james-page/docker && \
    add-apt-repository -y "deb https://clusterhq-archive.s3.amazonaws.com/ubuntu/$(lsb_release --release --short)/\$(ARCH) /" && \
    apt-get update && \
    apt-get -y --force-yes install clusterhq-flocker-node

RUN mkdir /etc/flocker
ADD start.sh /root/flocker-config/start.sh
ADD /agents/base-agent.yml /root/flocker-config/base-agent.yml
ADD /agents/aws-agent.yml /root/flocker-config/aws-agent.yml

EXPOSE 5423
EXPOSE 5424

VOLUME [ "/etc/flocker" ]

WORKDIR /root/flocker-config

ENTRYPOINT [ "/bin/bash", "-c", "start.sh" ]
