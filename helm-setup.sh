#!/usr/bin/env bash
set -x
set -e

if [ -x "$(command -v helm)" ]; then
    echo "Helm already exists, performing re-install"
    if [[ "`which helm`" != "/usr/local/bin/helm" ]]; then
        set +x
        echo "Already installed helm yourself in non-standard location? please remove it"
        exit -1
    fi
    sudo rm /usr/local/bin/helm
fi
if [ -x "$(command -v tiller)" ]; then
    echo "Tiller already exists, performing re-install"
    if [[ "`which tiller`" != "/usr/local/bin/tiller" ]]; then
        set +x
        echo "Already installed tiller yourself in non-standard location? please remove it"
        exit -1
    fi
    sudo rm /usr/local/bin/tiller
fi


HELM_RELEASE=helm-v2.11.0-linux-amd64

curl https://storage.googleapis.com/kubernetes-helm/$HELM_RELEASE.tar.gz --output $HELM_RELEASE.tar.gz && \
 tar -xzvf $HELM_RELEASE.tar.gz && \
 sudo cp linux-amd64/helm /usr/local/bin/helm && \
 sudo cp linux-amd64/tiller /usr/local/bin/tiller && \
 rm -fr linux-amd64 && rm -fr $HELM_RELEASE.tar.gz

# Load minikube context
~/minikube-ctx.sh

helm init --upgrade

set +x
>&2 echo "Successfully setted up helm, please execute ~/minikube-ctx.sh and then helm --help to start using it."
set -x


