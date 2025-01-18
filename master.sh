#! /bin/bash

# Update and upgrade all system packages to the latest versions
apt-get update -y
apt-get upgrade -y

# Set the hostname for the Kubernetes master node
hostnamectl set-hostname kube-master

# Install essential packages required for Kubernetes and Docker setup
apt-get install -y apt-transport-https ca-certificates curl gpg

# Add the Kubernetes package repository GPG key for secure downloads
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the Kubernetes package repository to the system sources list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package lists to include Kubernetes packages
apt-get update

# Install specific versions of Kubernetes components and Docker
apt-get install -y kubelet=1.32.0-1.1 kubeadm=1.32.0-1.1 kubectl=1.32.0-1.1 kubernetes-cni docker.io

# Prevent the installed Kubernetes packages from being automatically upgraded
apt-mark hold kubelet kubeadm kubectl

# Start and enable the Docker service to run on boot
systemctl start docker
systemctl enable docker

# Add the 'ubuntu' user to the Docker group to allow managing Docker without sudo
usermod -aG docker ubuntu
newgrp docker

# Configure sysctl settings for Kubernetes networking
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

# Apply the new sysctl settings
sudo sysctl --system

# Create a directory for containerd configuration
mkdir /etc/containerd

# Generate the default containerd configuration and save it to the config file
containerd config default | tee /etc/containerd/config.toml >/dev/null 2>&1

# Modify the containerd configuration to use the systemd cgroup driver
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Restart and enable the containerd service to apply changes and start on boot
systemctl restart containerd
systemctl enable containerd

# Pre-pull required Kubernetes images for the control plane components
kubeadm config images pull

# Initialize the Kubernetes cluster with a specified pod network CIDR and ignore preflight errors
kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=All

# Set up Kubernetes configuration for the 'ubuntu' user
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Apply the Flannel CNI plugin for pod networking
su - ubuntu -c 'kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml'

# Deploy the Rancher Local Path Provisioner for dynamic storage provisioning
su - ubuntu -c 'kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml'

# Patch the default storage class to set it as the default storage class
sudo -i -u ubuntu kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
