#!/usr/bin/env bash
set -x
set -e

# Load minikube context
. "$HOME/minikube-ctx.sh"

OWNHELM=0
if [ -x "$(command -v helm)" ]; then
    echo "Helm already exists, performing re-install"
    if [[ "`which helm`" != "/usr/local/bin/helm" ]]; then
        set +x
        echo "Already installed helm yourself?"
        echo "Please make sure it is up to date"
        read -p "Are you ready to proceed (y/n)? " answer
        case ${answer:0:1} in
            y|Y )
                echo Yes
            ;;
            * )
                exit -1
            ;;
        esac
        OWNHELM=1
        set -x
    fi

    read -p "Going to wipe out your existing helm settings (y/n)? " answer
    case ${answer:0:1} in
        y|Y )
            echo Yes
        ;;
        * )
            exit -1
        ;;
    esac
    sudo rm /usr/local/bin/helm || true
    sudo rm -fr "$HOME/.helm" || true
fi
OWNTILLER=0
if [ -x "$(command -v tiller)" ]; then
    echo "Tiller already exists, performing re-install"
    if [[ "`which tiller`" != "/usr/local/bin/tiller" ]]; then
        set +x
        echo "Already installed tiller yourself?"
        echo "Please make sure it is up to date"
        read -p "Are you ready to proceed (y/n)? " answer
        case ${answer:0:1} in
            y|Y )
                echo Yes
            ;;
            * )
                exit -1
            ;;
        esac
        OWNTILLER=1
        set -x
    fi
    read -p "Going to wipe out your existing tiller settings (y/n)? " answer
    case ${answer:0:1} in
        y|Y )
            echo Yes
        ;;
        * )
            exit -1
        ;;
    esac
    sudo rm /usr/local/bin/tiller || true
fi


HELM_RELEASE=helm-v2.11.0-linux-amd64

if [[ $OWNHELM -eq 0 ]] && [[ $OWNTILLER -eq 0 ]]; then
curl https://storage.googleapis.com/kubernetes-helm/$HELM_RELEASE.tar.gz --output $HELM_RELEASE.tar.gz && \
 tar -xzvf $HELM_RELEASE.tar.gz && \
 sudo cp linux-amd64/helm /usr/local/bin/helm && \
 sudo cp linux-amd64/tiller /usr/local/bin/tiller && \
 rm -fr linux-amd64 && rm -fr $HELM_RELEASE.tar.gz
fi

helm init --upgrade
kubectl rollout status -w deployment/tiller-deploy --namespace=kube-system

set +x
>&2 echo "Successfully setted-up helm, please execute `source ~/minikube-ctx.sh` and then helm --help to start using it."
set -x
