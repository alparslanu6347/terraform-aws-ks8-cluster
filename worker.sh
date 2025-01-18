#! /bin/bash

# Update and upgrade system packages
apt-get update -y  # Updates the package lists
apt-get upgrade -y  # Upgrades all installed packages to their latest versions

# Set the hostname for the worker node
hostnamectl set-hostname kube-worker

# Install necessary packages
sudo apt-get install -y unzip  # Installs unzip to handle zip files
sudo apt-get install -y apt-transport-https ca-certificates curl gpg  # Required tools for adding repositories and managing certificates

# Add the Kubernetes APT repository key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the Kubernetes APT repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package lists after adding the Kubernetes repository
apt-get update

# Install Kubernetes components and Docker
apt-get install -y kubelet=1.32.0-1.1 kubeadm=1.32.0-1.1 kubectl=1.32.0-1.1 kubernetes-cni docker.io

# Prevent automatic upgrades for Kubernetes components
apt-mark hold kubelet kubeadm kubectl

# Start and enable Docker service
systemctl start docker
systemctl enable docker

# Add the current user to the Docker group to avoid permission issues
usermod -aG docker ubuntu
newgrp docker

# Configure sysctl for Kubernetes networking
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1  # Enables IP forwarding
EOF
sysctl --system  # Reloads the sysctl configuration

# Configure containerd as the container runtime for Kubernetes
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml >/dev/null 2>&1

# Modify containerd configuration to use systemd as the cgroup driver
sed -i 's/SystemdCgroup \\= false/SystemdCgroup \\= true/g' /etc/containerd/config.toml

# Restart and enable containerd service
systemctl restart containerd
systemctl enable containerd

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.0.30.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Prepare the worker node to join the cluster
aws ec2 wait instance-status-ok --instance-ids ${master-id}  # Wait until the master node's status is 'ok'

# Generate an SSH key pair for secure communication with the master node
ssh-keygen -t rsa -f /home/ubuntu/kube_key -q -N ""

# Wait for the master node to be ready
sleep 60

# Send the SSH public key to the master node
aws ec2-instance-connect send-ssh-public-key \
  --region ${region} \
  --availability-zone ${master-zone} \
  --instance-id ${master-id} \
  --instance-os-user ubuntu \
  --ssh-public-key file:///home/ubuntu/kube_key.pub && \
# Check the master node status and wait until it is 'Ready'
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  -i /home/ubuntu/kube_key ubuntu@${master-private} \
  'while [ "$(kubectl get node | grep kube-master | awk '\''{print $2}'\'')" != "Ready" ]; do 
     echo "Waiting for master node to be Ready...";
     sleep 3;
   done'

# Retrieve the Kubernetes join command from the master node and execute it
aws ec2-instance-connect send-ssh-public-key \
  --region ${region} \
  --availability-zone ${master-zone} \
  --instance-id ${master-id} \
  --instance-os-user ubuntu \
  --ssh-public-key file:///home/ubuntu/kube_key.pub && \
join_command=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
  -i /home/ubuntu/kube_key ubuntu@${master-private} "kubeadm token create --print-join-command") && \
eval "$join_command"
