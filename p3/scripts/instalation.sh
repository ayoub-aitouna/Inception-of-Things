#!/bin/bash

InstallDocker() {
  if [ -x "$(command -v docker)" ]; then
    echo "INFO: Docker is already installed"
    return
  fi
  echo "Installing Docker ....."

  apt-get install ca-certificates curl -y
  install -m 0755 -d /etc/apt/keyrings

  distro=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
  curl -fsSL https://download.docker.com/linux/$distro/gpg -o /etc/apt/keyrings/docker.asc

  chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$distro \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
    tee /etc/apt/sources.list.d/docker.list >/dev/null
  apt-get update -y
  sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

  # Add your user to the docker group:
  getent group docker || groupadd docker
  usermod -aG docker $USER

  echo "Docker installed successfully"

}

InstallK3D() {
  if [ -x "$(command -v k3d)" ]; then
    echo "INFO: KubeK3D is already installed"
    return
  fi
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
}

InstallKubeCtl() {
  if [ -x "$(command -v kubectl)" ]; then
    echo "INFO: Kubectl is already installed"
    return
  fi
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
}

StartnConfigureCluster() {

  echo "Creating/Configuring k3d $1 cluster ....."

  k3d cluster create $1 --api-port 6550 --servers 1 --agents 3 --port 8080:80@loadbalancer --port 32000:32000@agent:0 --volume $(pwd)/vagrant:/src@all --wait
  k3d kubeconfig merge $1 --kubeconfig-merge-default --kubeconfig-switch-context

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


  # a rollout to wait for argocd to spin up
  kubectl rollout status deployment argocd-server -n argocd

  kubectl apply -f conf/argocd.ingress.yaml
  kubectl apply -f conf/application.yaml

  echo "$1 Cluster created and configured successfully"
}

AddDnsRecord() {
  echo "Adding DNS record $1 $2"
  host = $1
  ip = $2
  if ! grep -q "$host" /etc/hosts; then
    echo "$ip $host" >>/etc/hosts
  fi
}

ConfigureDns() {
  ip=$(ip -4 addr show docker0 | grep -oP 'inet \K[\d.]+')
  AddDnsRecord "argo.org.local" $ip
  AddDnsRecord "app1.com" $ip
}

if [ $(id -u) -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit
fi

flag_update=false

while getopts "u" option; do
  case $option in
  u)
    flag_update=true
    ;;
  ?)
    exit 1
    ;;
  esac
done

# Shift off the processed options
shift $((OPTIND - 1))

if [ "$flag_update" = true ]; then
  apt-get update -y
fi

InstallDocker
InstallK3D
InstallKubeCtl
StartnConfigureCluster "Demo"
