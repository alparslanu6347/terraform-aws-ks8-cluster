# Terraform Module for Provisioning a Kubernetes Cluster on AWS EC2 with 1 Master and 1 Worker Node using Ubuntu 22.04 AMI

- This Terraform module provides an automated solution for provisioning a simple Kubernetes cluster on AWS EC2 instances, consisting of one master node and one worker node. It uses the Ubuntu 22.04 AMI and is designed for educational and demonstration purposes, showcasing how to create and configure a Kubernetes cluster environment in the cloud.

- master.sh includes :

  - System updates and package installation: Updates the system and installs necessary dependencies for Kubernetes and Docker.

  - Kubernetes components installation: Installs kubelet, kubeadm, kubectl, and kubernetes-cni components for Kubernetes.

  - Docker installation: Installs Docker to be used as the container runtime for Kubernetes.

  - Kernel and container configurations: Configures the kernel and container settings to ensure proper functioning of 
  Kubernetes.

  - Kubernetes Master initialization: Initializes the Kubernetes master node using kubeadm.

  - Kubeconfig setup: Copies the kubeconfig file to the user’s home directory to allow kubectl to interact with the cluster.

  - Flannel CNI installation: Deploys the Flannel network plugin to manage networking between pods.

  - Local Path Storage setup: Deploys and configures the Local Path Provisioner for persistent storage in the cluster.
  - Storage class configuration: Marks the Local Path Storage as the default storage class.
  
- worker.sh includes :

  - System updates and package installation: Updates the worker node and installs the necessary dependencies like Kubernetes components and Docker.

  - Kubernetes components installation: Installs kubelet, kubeadm, kubectl, and kubernetes-cni to allow the worker node to join the Kubernetes cluster.

  - Docker installation: Installs Docker as the container runtime for Kubernetes on the worker node.

  - Containerd configuration: Configures containerd for Kubernetes to use as the container runtime.

  - Kubelet service management: Ensures that the kubelet service is running and enabled on the worker node.

  - Joining the Kubernetes Cluster: The worker node uses kubeadm join to join the cluster, passing the necessary token and certificate information from the master node.

  - Monitoring Master Node Status: The worker node waits for the master node to be ready before joining the cluster.

  - Installing EC2 Instance Connect CLI and other utilities: Installs the EC2 Instance Connect CLI and mssh utility to simplify communication between nodes.

- This module is not intended for production use and is provided as an example for training purposes.

- It is designed to showcase the process of creating and publishing a module in the Terraform Registry.

- Important option :

  ***If you want enhanced security replace `variable "allowed_ip"` default value with your secure IP address***


Usage:

```hcl

provider "aws" {
  region = "us-east-1"
}

module "k8s-cluster" {
    source   = "alparslanu6347/k8s-cluster/aws"
    key_name = "mykey"
    subnet   = "subnet-a12bb345"
    azone    = "us-east-1a"
}
```