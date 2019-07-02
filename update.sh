#!/bin/bash

if [ -z ${PLUGIN_NAMESPACE} ]; then
  PLUGIN_NAMESPACE="default"
fi

if [ -z ${PLUGIN_KUBERNETES_USER} ]; then
  PLUGIN_KUBERNETES_USER="default"
fi

if [ ! -z ${PLUGIN_KUBERNETES_TOKEN} ]; then
  KUBERNETES_TOKEN=$PLUGIN_KUBERNETES_TOKEN
fi

if [ ! -z ${PLUGIN_KUBERNETES_SERVER} ]; then
  KUBERNETES_SERVER=$PLUGIN_KUBERNETES_SERVER
fi

if [ ! -z ${PLUGIN_KUBERNETES_CERT} ]; then
  KUBERNETES_CERT=${PLUGIN_KUBERNETES_CERT}
fi

kubectl config set-credentials default --token=${KUBERNETES_TOKEN}
if [ ! -z ${KUBERNETES_CERT} ]; then
  echo ${KUBERNETES_CERT} | base64 -d > ca.crt
  kubectl config set-cluster default --server=${KUBERNETES_SERVER} --certificate-authority=ca.crt
else
  echo "WARNING: Using insecure connection to cluster"
  kubectl config set-cluster default --server=${KUBERNETES_SERVER} --insecure-skip-tls-verify=true
fi

kubectl config set-context default --cluster=default --user=${PLUGIN_KUBERNETES_USER}
kubectl config use-context default

TAG=${PLUGIN_TAG}

# Use .tags file option
# Default is FALSE unless value of USE_TAGS_FILE is one of y,Y,t,T,true,TRUE,yes,YES
# the .tags file was used by the docker plugin when we created out container
# a .tags file is a comma separated list of tags: 1.0.1,1.0,1,latest (see docker plugin docs)
# We will use the first tag in the list, so create your file accordingly

USE_TAGS_FILE=`echo $PLUGIN_USE_TAGS_FILE | tr [a-z] [A-Z]`
[[ "X$USE_TAGS_FILE" == "XY" ]] || [[ "X$USE_TAGS_FILE" == "XTRUE" ]] || [[ "X$USE_TAGS_FILE" == "XYES" ]] && USE_TAGS_FILE=T
[[ -f .tags ]] && [[ "X$USE_TAGS_FILE" == "XT" ]] && TAG=`cat .tags | tr -d \" | cut -d, -f1`

# kubectl version
IFS=',' read -r -a DEPLOYMENTS <<< "${PLUGIN_DEPLOYMENT}"
IFS=',' read -r -a CONTAINERS <<< "${PLUGIN_CONTAINER}"
for DEPLOY in ${DEPLOYMENTS[@]}; do
  echo Deploying ${PLUGIN_REPO}:${TAG} to $KUBERNETES_SERVER
  for CONTAINER in ${CONTAINERS[@]}; do
    if [[ ${PLUGIN_FORCE} == "true" ]]; then
      kubectl -n ${PLUGIN_NAMESPACE} set image deployment/${DEPLOY} \
        ${CONTAINER}=${PLUGIN_REPO}:${TAG}FORCE
    fi
    kubectl -n ${PLUGIN_NAMESPACE} set image deployment/${DEPLOY} \
      ${CONTAINER}=${PLUGIN_REPO}:${TAG} --record
  done
done
