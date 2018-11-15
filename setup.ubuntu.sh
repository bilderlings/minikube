#!/usr/bin/env bash
set -x
set -e

if [[ "`gcc --version`" != *ubuntu* ]]
then
    set +x
    echo "Docker auto-install works on ubuntu only, sorry mac-ers and non-ubunters"
    exit -1
fi

sudo apt-get update

if [ -x "$(command -v docker)" ]; then
    echo "Docker exists, skip installation"
    if [[ "`docker --version`" != *18.06.1* ]]
    then
        set +x
        echo "Your docker version is not 18.06.1 CE: `docker --version` please upgrade/downgrade yourself"
        echo "NOTE: you will loose containers!, if OK, then execute the following to downgrade/upgrade" 
        echo "sudo service docker stop"
        echo "sudo rm -fr /var/lib/docker"
        echo "sudo apt-get remove docker-ce"
        echo "sudo apt-get install docker-ce=18.06.1~ce~3-0~ubuntu"
        echo "Close & Open your current terminal after this is done, and rerun make"
        exit -1
    fi
else
    echo "Install docker requirements"
    sudo apt-get install apt-transport-https ca-certificates curl software-properties-common
    echo "install docker repo"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
    sudo apt-get update
    sudo apt-get install docker-ce=18.06.1~ce~3-0~ubuntu
fi

echo "Starting minikube installation"

if [ -x "$(command -v minikube)" ]; then
    echo "Minikube already exists, performing re-install"
    if [[ "`which minikube`" != "/usr/local/bin/minikube" ]]; then
        set +x
        echo "Already installed minikube yourself in non-standard location or with apt? please remove it"
        echo "Used apt? then please run `sudo apt remove minikube`"
        echo "Simply installed it not in /usr/local/bin?"
        echo "Please run 'sudo rm `which minikube`'"
        echo "Close & Open your current terminal after this is done and rerun make"
        exit -1
    fi
    sudo minikube stop || true
    sudo minikube delete || true
    sudo rm -fr $HOME/.minikube || true
    sudo rm -fr /data/minikube || true
    sudo rm -fr $HOME/.kube/config.minikube || true
    sudo rm -fr /var/lib/kubeadm.yaml
    sudo systemctl stop '*kubelet*.mount'
    sudo rm -fr /var/lib/kubelet
    sudo rm -rf /etc/kubernetes/
    sudo rm /usr/local/bin/minikube
    sudo rm -fr /var/minikube
fi

if [ -x "$(command -v kubectl)" ]; then
    echo "Kubectl already exists, performing re-install"
    if [[ "`which kubectl`" != "/usr/local/bin/kubectl" ]]; then
        set +x
        echo "Already installed kubectl yourself? please remove"
        echo "Used apt? remove it by 'sudo apt-get remove kubectl'"
	echo "Simply installed it not in /usr/local/bin?"
        echo "Then remove it with 'sudo rm `which kubectl`'"
        echo "Close & Open your current termina after this is done"
        exit -1
    fi
    sudo rm /usr/local/bin/kubectl
fi

curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo cp minikube /usr/local/bin/ && rm minikube
curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && sudo cp kubectl /usr/local/bin/ && rm kubectl


# install hidden deps of kubectl
sudo apt-get install socat

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
echo "export KUBECONFIG=$HOME/.kube/config.minikube" >>$HOME/minikube-ctx.sh
echo "export KUBECONTEXT=minikube" >>$HOME/minikube-ctx.sh
chmod +x $HOME/minikube-ctx.sh

kubectl delete --namespace kube-system secret ca-key-pair || true
kubectl create --namespace kube-system secret tls ca-key-pair \
   --cert="$HOME/minikube-ca.crt" \
   --key="$HOME/minikube-ca.key"

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
>&2 echo "minikube setup was successfull, please run ~/minikube-ctx.sh before you will use kubectl, it will set your context accordingly"
set -x
