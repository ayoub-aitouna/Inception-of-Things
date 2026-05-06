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

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$distro \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
    tee /etc/apt/sources.list.d/docker.list >/dev/null
  apt-get update -y
  sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

  getent group docker || groupadd docker
  usermod -aG docker vagrant  # FIX 1: was $USER, should be vagrant

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

  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

  chmod 644 /etc/apt/sources.list.d/kubernetes.list
  apt-get update

  apt-get install -y kubectl

  echo "kubectl installed successfully"
}

StartnConfigureCluster() {
  # FIX 2: delete cluster if already exists to avoid FATA error on re-run
  if k3d cluster list | grep -q "$1"; then
    echo "Cluster '$1' already exists, deleting it..."
    k3d cluster delete $1
  fi

  echo "Creating/Configuring k3d $1 cluster ....."

  # FIX 3: removed --volume $(pwd)/vagrant:/src@all (path doesn't exist)
  k3d cluster create $1 --api-port 6550 --servers 1 --agents 2 --port 8080:80@loadbalancer --port 32000:32000@agent:0 --wait
  k3d kubeconfig merge $1 --kubeconfig-merge-default --kubeconfig-switch-context

  # install argocd
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  kubectl patch deployment argocd-server -n argocd \
    --type='json' \
    -p='[{
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--insecure"
    }]'

  # Install Nginx Ingress Controller
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

  kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx --timeout=300s

  kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
    --type='json' \
    -p='[{
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--enable-ssl-passthrough"
    }]'

  kubectl rollout status deployment argocd-server -n argocd --timeout=300s

  # FIX 4: wait for nginx webhook before applying ingress
  echo "Waiting for nginx webhook to be ready..."
  until kubectl get endpoints -n ingress-nginx ingress-nginx-controller-admission \
    -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -q "[0-9]"; do
    sleep 3
  done
  sleep 5

  # FIX 5: use /vagrant prefix so paths work inside VM
  kubectl apply -f /vagrant/conf/argocd.ingress.yaml
  kubectl apply -f /vagrant/conf/application.yaml

  echo "$1 Cluster created and configured successfully"

  # FIX 6: setup kubeconfig for vagrant user
  mkdir -p /home/vagrant/.kube
  k3d kubeconfig get $1 > /home/vagrant/.kube/config
  chown -R vagrant:vagrant /home/vagrant/.kube
}

AddDnsRecord() {
  echo "Adding DNS record $1 $2"
  host=$1
  ip=$2  
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

shift $((OPTIND - 1))

if [ "$flag_update" = true ]; then
  apt-get update -y
fi

InstallDocker
InstallK3D
InstallKubeCtl
StartnConfigureCluster "Demo"
ConfigureDns  # was missing from original

echo ""
echo "Done!"
echo "Argo CD UI: http://argo.org.local:8080"
echo "Admin password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"