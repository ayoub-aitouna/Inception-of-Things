#!/bin/bash
if [ $(id -u) -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit
fi

apt update

apt install linux-headers-$(uname -r) build-essential dkms -y

curl -o  https://download.virtualbox.org/virtualbox/7.0.22/virtualbox-7.0_7.0.22-165102~Debian~bookworm_amd64.deb
dpkg -i virtualbox-7.0_7.0.22-165102~Debian~bookworm_amd64.deb

apt-get install -f -y
/sbin/vboxconfig

wget -O hashicorp.gpg https://apt.releases.hashicorp.com/gpg
gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg hashicorp.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

apt install vagrant -y