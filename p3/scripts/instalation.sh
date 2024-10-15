#!/bin/bash

# Add Docker's official GPG key:
apt-get update -y

############# STARTED DOCKER INSTALATION ########################

echo "Installing Docker ....."

apt-get install ca-certificates curl -y
install -m 0755 -d /etc/apt/keyrings

distro=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
curl -fsSL https://download.docker.com/linux/$distro/gpg -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$distro \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Add your user to the docker group:
getent group docker || groupadd docker
usermod -aG docker $USER

echo "Docker installed successfully"

############# COMPILTED DOCKER INSTALATION ########################

curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

############ STARTED KUBECTL INSTALATION ########################

echo "Installing kubectl ....."

apt-get install -y apt-transport-https ca-certificates curl gnupg

# Download the public signing key for the Kubernetes package repositories
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# allow unprivileged APT programs to read this keyring
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

chmod 644 /etc/apt/sources.list.d/kubernetes.list
apt-get update

# Install kubectl
apt-get install -y kubectl 

echo "kubectl installed successfully"

############# COMPLETED KUBECTL INSTALATION ########################

############# STARTED CREATING/CONFIGURING CLUSTER ########################

echo "Creating/Configuring k3d cluster ....."

k3d cluster create demo --api-port 6550 --servers 1 --agents 3  --port 8080:80@loadbalancer --port 32000:32000@agent:0 --volume $(pwd)/vagrant:/src@all --wait
k3d kubeconfig merge demo --kubeconfig-merge-default --kubeconfig-switch-context

# install argocd
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Adding --insecure flag to the argocd-server container because we are using self-signed certificates
kubectl patch deployment argocd-server -n argocd \
--type='json' \
-p='[{
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--insecure"
}]'

# Install Nginx Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Waiting for the deployment to be read
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx

# adding --enable-ssl-passthrough flag to the ingress-nginx-controller container
# because we are using self-signed certificates
kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
--type='json' \
-p='[{
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--enable-ssl-passthrough"
}]'

kubectl apply -f conf/argocd.ingress.yaml
kubectl apply -f conf/application.yaml

echo "Cluster created and configured successfully"
############# STARTED CREATING/CONFIGURING CLUSTER ########################
