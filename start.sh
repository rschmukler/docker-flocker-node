#!/bin/bash

# Variables to configure:
# FLOCKER_CONTROL_MODE - whether we are running as control or node
# FLOCKER_CONTROL_HOST - the hostname of our control server
# FLOCKER_CONTROL_PORT - the port of our control server
# FLOCKER_DATASET_BACKEND - the backend to use. eg. aws
# FLOCKER_DATASET_AWS_REGION
# FLOCKER_DATASET_AWS_ZONE 
# FLOCKER_DATASET_AWS_KEY
# FLOCKER_DATASET_AWS_SECRET

FLOCKER_CONTROL_MODE=${FLOCKER_CONTROL_MODE:-false}
FLOCKER_CONTROL_PORT="${FLOCKER_CONTROL_PORT:-4524}"

CLUSTER_CRT=/etc/flocker/cluster.crt
CONTROL_CRT=/etc/flocker/control-service.crt
CONTROL_KEY=/etc/flocker/control-service.key
NODE_CRT=/etc/flocker/node.crt
NODE_KEY=/etc/flocker/node.key


if  [ $FLOCKER_CONTROL_MODE = "true" ]; then
  echo "Running in control mode...";
fi

function checkCerts() {
  cp /certs/* /etc/flocker
  chmod 0700 /etc/flocker

  if [ ! -f $CLUSTER_CRT ]; then
    echo "Missing cluster cert ($CLUSTER_CRT)"
    exit 1
  fi
  chmod 0600 $CLUSTER_CRT

  if [ $FLOCKER_CONTROL_MODE = "true" ]; then 
    if [ ! -f $CONTROL_KEY ]; then
      echo "Missing control-service key ($CONTROL_KEY)"
      exit 1
    fi
    chmod 0600 $CONTROL_KEY
  fi

  if [ ! -f $CONTROL_CRT ]; then
    echo "Missing control-service cert ($CONTROL_CRT)"
    exit 1
  fi
  chmod 0600 $CONTROL_CRT

  if [ $FLOCKER_CONTROL_MODE = "false" ]; then
    if [ ! -f $NODE_KEY ]; then
      echo "Missing node key ($NODE_KEY)"
      exit 1
    fi
    chmod 0600 $NODE_KEY

    if [ ! -f $NODE_CRT ]; then
      echo "Missing node cert ($NODE_CRT)"
      exit 1
    fi
    chmod 0600 $NODE_CRT
  fi
}

function buildAgent() {
  AGENT_FILE=/etc/flocker/agent.yml
  BASE_FILE=/root/flocker-config/base-agent.yml

  if [ -z "$FLOCKER_CONTROL_HOST" ]; then
    echo "No FLOCKER_CONTROL_HOST specified. Exiting..."
    exit 1
  fi

  sed -i 's/CONTROL_HOST/'$FLOCKER_CONTROL_HOST'/' $BASE_FILE
  sed -i 's/CONTROL_PORT/'$FLOCKER_CONTROL_PORT'/' $BASE_FILE

  cat $BASE_FILE > $AGENT_FILE

  if [ $FLOCKER_DATASET_BACKEND = "aws" ]; then
    AWS_FILE=/root/flocker-config/aws-agent.yml
    sed -i 's/AWS_REGION/'$FLOCKER_DATASET_AWS_REGION'/' $AWS_FILE
    sed -i 's/AWS_ZONE/'$FLOCKER_DATASET_AWS_ZONE'/' $AWS_FILE
    sed -i 's/AWS_KEY/'$FLOCKER_DATASET_AWS_KEY'/' $AWS_FILE
    sed -i 's/AWS_SECRET/'$FLOCKER_DATASET_AWS_SECRET'/' $AWS_FILE
    cat $AWS_FILE >> $AGENT_FILE
  fi
}

function runFlocker() {
  echo "Starting Flocker..."
  FLOCKER_CTRL_PATH=/usr/sbin/flocker-control
  FLOCKER_DATASET_AGENT_PATH=/usr/sbin/flocker-dataset-agent
  FLOCKER_CONTAINER_AGENT_PATH=/usr/sbin/flocker-container-agent
  if [ $FLOCKER_CONTROL_MODE = "true" ]; then 
    $FLOCKER_CTRL_PATH -p tcp:4523 -a tcp:$FLOCKER_CONTROL_PORT
  else
    $FLOCKER_DATASET_AGENT_PATH &
    $FLOCKER_CONTAINER_AGENT_PATH &
  fi
}

function runFlockerPlugin() {
  echo "Starting Flocker Plugin..."
  export FLOCKER_CONTROL_SERVICE_BASE_URL=https://${FLOCKER_CONTROL_HOST}:${FLOCKER_CONTROL_PORT}/v1
  export MY_NETWORK_IDENTITY=`hostname -I | awk '{print $2}'`
  flocker-docker-plugin &
}

function startDocker() {
  echo "Starting Docker..."
  set -x -e

  TLS_PATH=/etc/docker/tls
  CGROUPS="perf_event net_cls freezer devices blkio memory cpuacct cpu cpuset"

  mkdir -p /sys/fs/cgroup
  mount -t tmpfs none /sys/fs/cgroup

  for i in $CGROUPS; do
      mkdir -p /sys/fs/cgroup/$i
      mount -t cgroup -o $i none /sys/fs/cgroup/$i
  done

  if ! lsmod | grep -q br_netfilter; then
      modprobe br_netfilter 2>/dev/null || true
  fi

  rm -f /var/run/docker.pid

  ARGS=$(echo $(ros config get user_docker.args | sed 's/^-//'))
  ARGS="$ARGS $(echo $(ros config get user_docker.extra_args | sed 's/^-//'))"

  if [ "$(ros config get user_docker.tls)" = "true" ]; then
      ARGS="$ARGS $(echo $(ros config get user_docker.tls_args | sed 's/^-//'))"
      ros tls generate --server -d $TLS_PATH
      cd $TLS_PATH
  fi

  if [ -e /var/lib/rancher/conf/docker ]; then
      source /var/lib/rancher/conf/docker
  fi

  exec $ARGS $DOCKER_OPTS >/var/log/docker.log 2>&1
}

checkCerts
buildAgent
runFlocker
if [ "$FLOCKER_CONTROL_MODE" != "true" ]; then 
  startDocker
  runFlockerPlugin
fi
