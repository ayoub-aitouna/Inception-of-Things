apt-get update -y
apt install net-tools -y
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode=644

while [ ! -d /vagrant ]; do
    echo "Waiting for /vagrant to be ready..."
    sleep 2
done

kubectl apply -f /vagrant/conf/