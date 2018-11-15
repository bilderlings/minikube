#!/usr/bin/env bash
set -x
set -e

# Load minikube context
~/minikube-ctx.sh

helm del --purge cert-manager || true
kubectl delete customresourcedefinitions.apiextensions.k8s.io certificates.certmanager.k8s.io || true
kubectl delete customresourcedefinitions.apiextensions.k8s.io clusterissuers.certmanager.k8s.io || true
kubectl delete customresourcedefinitions.apiextensions.k8s.io issuers.certmanager.k8s.io || true

tiller-deploy

helm install --wait \
    --name cert-manager \
    --namespace kube-system \
    stable/cert-manager

# time ti setup CA certs
COMMON_NAME="minikube.iamoffice.lv"
if [ -f "$HOME/minikube-ca.key" ]; then
   echo "minikube CA cert exists, will be using it"
else
   echo "Generating new CA cert"
   openssl genrsa -out $HOME/minikube-ca.key 2048
   openssl req -x509 -new -nodes -key "$HOME/minikube-ca.key" -subj "/CN=${COMMON_NAME}" -days 3650 -reqexts v3_req -extensions v3_ca -out "$HOME/minikube-ca.crt"
fi

kubectl delete --namespace kube-system secret ca-key-pair || true
kubectl create --namespace kube-system secret tls ca-key-pair \
   --cert="$HOME/minikube-ca.crt" \
   --key="$HOME/minikube-ca.key"

kubectl delete --namespace kube-system clusterissuer letsencrypt || true
kubectl create --namespace kube-system -f - << EOF
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  ca:
    secretName: ca-key-pair
EOF
set +x
>&2 echo "Successfully setted-up cert-manager"
>&2 echo "PLEASE INSTALL & ACCEPT THIS CA CERT IN YOUR BROWSER: $HOME/minikube-ca.crt"
set -x


