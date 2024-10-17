#!/bin/bash

InstallHelm() {
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg >/dev/null
    apt-get install apt-transport-https --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
    apt-get update
    apt-get install helm
}

InstallGitLab() {
    # Adds the GitLab Helm chart repository.
    helm repo add gitlab https://charts.gitlab.io/
    # Updates your local Helm repository index to get the latest chart versions.
    helm repo update

    kubectl create namespace gitlab
    helm upgrade --install gitlab gitlab/gitlab \
        --namespace gitlab --timeout 600s -f conf/gitlab/values.yaml
}

# check if helm is installed
if ! [ -x "$(command -v helm)" ]; then
    echo "INFO: Helm is not installed. Installing Helm"
    InstallHelm
else
    echo "INFO: Helm is already installed"
fi

InstallGitLab
