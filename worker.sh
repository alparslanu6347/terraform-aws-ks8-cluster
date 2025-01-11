#! /bin/bash
apt-get update -y
apt-get upgrade -y
hostnamectl set-hostname kube-worker
sudo apt-get install -y unzip
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet=1.32.0-1.1 kubeadm=1.32.0-1.1 kubectl=1.32.0-1.1 kubernetes-cni docker.io
apt-mark hold kubelet kubeadm kubectl
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu
newgrp docker
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
# cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
# overlay
# br_netfilter
# EOF
# modprobe overlay
# modprobe br_netfilter
# cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
# net.bridge.bridge-nf-call-iptables  = 1
# net.bridge.bridge-nf-call-ip6tables = 1
# net.ipv4.ip_forward                 = 1
# EOF
sysctl --system
mkdir /etc/containerd
containerd config default | tee /etc/containerd/config.toml >/dev/null 2>&1
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd
# install aws cli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.0.30.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
# Join the worker node
aws ec2 wait instance-status-ok --instance-ids ${master-id}
ssh-keygen -t rsa -f /home/ubuntu/kube_key -q -N ""
sleep 60
aws ec2-instance-connect send-ssh-public-key --region ${region} --availability-zone ${master-zone} --instance-id ${master-id} --instance-os-user ubuntu --ssh-public-key file:///home/ubuntu/kube_key.pub && ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /home/ubuntu/kube_key ubuntu@${master-private} 'until [ "$(kubectl get node | awk '\''/kube-master/ {print $2}'\'')" == "Ready" ]; do sleep 3; done'
aws ec2-instance-connect send-ssh-public-key --region ${region} --availability-zone ${master-zone} --instance-id ${master-id} --instance-os-user ubuntu --ssh-public-key file:///home/ubuntu/kube_key.pub \
&& eval "$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  \
-i /home/ubuntu/kube_key ubuntu@${master-private} kubeadm token create --print-join-command)"