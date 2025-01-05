variable "key_name" {    // !!! This is a required input !!!
  type        = string
#   default = "arrow"
  description = "The name of the SSH key pair used to access EC2 instances. This is a required input, and there is no default value."
}

variable "subnet" {     // !!! This is a required input !!!
  type        = string
#   default     = "subnet-c41ba589" 
  description = "The subnet ID for deploying resources in the Availability Zone (example = us-east-1a) you chose. Ensure instances are in the same AZ to minimize inter-AZ data transfer costs. This is a required input, and there is no default value."
}

variable "azone" {      // !!! This is a required input !!!
  type        = string
#   default     = "us-east-1a"
  description = "The Availability Zone (AZ) where resources will be deployed. Choose the AZ that best suits your requirements. This is a required input, and there is no default value."
}

variable "instance_type" {
  type        = string
  default     = "t3a.medium"
  description = "The instance type for the Ubuntu 22.04 server."
}

variable "ami" {
  type        = string
  default     = "ami-005fc0f236362e99f"
  description = "The Amazon Machine Image (AMI) ID for the Ubuntu 22.04 operating system."
}


variable "sec-gr-mutual" {
  type        = string
  default     = "k8s-mutual-sec-group"
  description = "The name of the security group used for mutual communication between Kubernetes nodes."
}

variable "sec-gr-k8s-master" {
  type        = string
  default     = "k8s-master-sec-group"
  description = "The name of the security group assigned to Kubernetes master nodes."
}

variable "sec-gr-k8s-worker" {
  type        = string
  default     = "k8s-worker-sec-group"
  description = "The name of the security group assigned to Kubernetes worker nodes." 
}

variable "allowed_ip" {  
  type        = string
  default     = "0.0.0.0/0"
  description = "The IP address allowed for SSH access. If you want enhanced security, replace this default value with your secure IP address. Optional"
}