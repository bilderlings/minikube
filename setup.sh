#!/usr/bin/env bash
set -x
set -e

UBUNTU=0
DOKER_VERSION=18.06.1
DOCKER_VERSION_UBUNTU=18.06.1~ce~3-0~ubuntu
if [[ "`gcc --version`" != *ubuntu* ]]
then
    set +x
    echo "Docker auto-install works on ubuntu only, sorry"
    echo "1) Please install YOURSELF docker $DOKER_VERSION~ce version by whatever means you want"
    echo "2) Install latest YOURSELF version of socat"
    read -p "Are you ready to proceed (y/n)? " answer
    case ${answer:0:1} in
        y|Y )
            echo Yes
        ;;
        * )
            exit -1
        ;;
    esac
    set -x
else
    UBUNTU=1
    sudo apt update
    # install hidden deps of kubectl
    sudo apt-get install socat
fi

if [ -x "$(command -v docker)" ]; then
    echo "Docker exists, skip installation"
    if [[ "`docker --version`" != *$DOCKER_VERSION* ]]
    then
        set +x
        echo "Your docker version is not $DOKER_VERSION CE: `docker --version` please upgrade/downgrade yourself"
        echo "NOTE: you will loose containers!, if OK, then execute the following to downgrade/upgrade" 
        echo "sudo service docker stop"
        echo "sudo rm -fr /var/lib/docker"
        echo "sudo apt-get remove docker-ce"
        echo "sudo apt-get install docker-ce=$DOCKER_VERSION_UBUNTU"
        read -p "Are you ready to proceed (y/n)? " answer
        case ${answer:0:1} in
            y|Y )
                echo Yes
            ;;
            * )
                exit -1
            ;;
        esac
        set -x
    fi
elif [ "$UBUNTU" -eq 1 ]; then
    echo "Install docker requirements"
    sudo apt-get install apt-transport-https ca-certificates curl software-properties-common
    echo "install docker repo"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
    sudo apt-get update
    sudo apt-get install docker-ce=$DOCKER_VERSION_UBUNTU
fi

echo "Starting minikube installation"
OWNMINIKUBE=0
if [ -x "$(command -v minikube)" ]; then
    echo "Minikube already exists"
    if [[ "`which minikube`" != "/usr/local/bin/minikube" ]]; then
        set +x
        echo "Already installed minikube yourself?"
        echo "Make sure it is up to date"
        read -p "Are you ready to proceed (y/n)? " answer
        case ${answer:0:1} in
            y|Y )
                echo Yes
            ;;
            * )
                exit -1
            ;;
        esac
        OWNMINIKUBE=1
        set -x
    fi
    read -p "Going to wipe out your existing minikube settings (y/n)? " answer
    case ${answer:0:1} in
        y|Y )
            echo Yes
        ;;
        * )
            exit -1
        ;;
    esac
    # minikube has no uninstaller:)
    # if you will delete any of the following, minikube will fail to reinstall:) super Resilient!
    sudo minikube stop || true
    sudo minikube delete || true
    sudo rm -fr $HOME/.minikube || true
    sudo rm -fr /data/minikube || true
    sudo rm -fr $HOME/.kube/config.minikube || true
    sudo rm -fr /var/lib/kubeadm.yaml
    sudo systemctl stop '*kubelet*.mount'
    sudo rm -fr /var/lib/kubelet
    sudo systemctl stop kubelet.service || true
    CONTAINERS=`sudo docker ps -a | grep "[ ]k8s_" | awk '{print $1}'
    sudo docker stop "$CONTAINERS"
    sudo docker rm "$CONTAINERS"
    sudo rm -rf /etc/kubernetes/
    sudo rm /usr/local/bin/minikube || true
    sudo rm -fr /var/minikube
fi

OWNKUBECTL=0
if [ -x "$(command -v kubectl)" ]; then
    echo "Kubectl already exists"
    if [[ "`which kubectl`" != "/usr/local/bin/kubectl" ]]; then
        set +x
        echo "Already installed kubectl yourself?"
        echo "Please make sure it is at latest version"
        echo "Make sure it is up to date"
        read -p "Are you ready to proceed (y/n)? " answer
        case ${answer:0:1} in
            y|Y )
                echo Yes
            ;;
            * )
                exit -1
            ;;
        esac
        OWNKUBECTL=1
        set +x
    fi
    sudo rm /usr/local/bin/kubectl || true
fi

if [ "$OWNMINIKUBE" -eq 0 ]; then
curl -Lo minikube https://github.com/kubernetes/minikube/releases/download/v0.30.0/minikube-linux-amd64 && \
 chmod +x minikube && \
 sudo cp minikube /usr/local/bin/ && \
 rm minikube
fi

if [ "$OWNKUBECTL" -eq 0 ]; then
curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/v1.12.2/bin/linux/amd64/kubectl && \
 chmod +x kubectl && \
 sudo cp kubectl /usr/local/bin/ && \
 rm kubectl
fi

export MINIKUBE_WANTUPDATENOTIFICATION=false
export MINIKUBE_WANTREPORTERRORPROMPT=false
export MINIKUBE_HOME=$HOME
export CHANGE_MINIKUBE_NONE_USER=true
mkdir -p $HOME/.kube
mkdir -p $HOME/.minikube
touch $HOME/.kube/config.minikube

export KUBECONFIG=$HOME/.kube/config.minikube
sudo -E minikube start --vm-driver=none

# this for loop waits until kubectl can access the api server that Minikube has created
for i in {1..150}; do # timeout for 5 minutes
   kubectl get po &> /dev/null
   if [ $? -ne 1 ]; then
      break
  fi
  sleep 2
done

# enable ingress
sudo minikube addons enable ingress

# install helm

echo "#!/usr/bin/env bash" >$HOME/minikube-ctx.sh
echo "set -x" >>$HOME/minikube-ctx.sh
echo "export KUBECONFIG=$HOME/.kube/config.minikube" >>$HOME/minikube-ctx.sh
echo "export KUBECONTEXT=minikube" >>$HOME/minikube-ctx.sh
echo "export KUBENAMESPACE=minikube" >>$HOME/minikube-ctx.sh
echo "export CONFIG_SUFFIX=minikube" >>$HOME/minikube-ctx.sh
echo "set +x" >>$HOME/minikube-ctx.sh

chmod +x $HOME/minikube-ctx.sh

kubectl delete --namespace default PersistentVolume minikube-pv || true
kubectl create --namespace default -f - << EOF
kind: PersistentVolume
apiVersion: v1
metadata:
  name: minikube-pv
  labels:
    type: local
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/var/minikube"
EOF

set +x
>&2 echo "minikube setup was successfull, please run 'source ~/minikube-ctx.sh' before you will use kubectl, it will set your context accordingly"
set -x
