output master-ip {
  value       = aws_instance.master.public_ip
  sensitive   = false
  description = "public ip of the master"
}

output worker-ip {
  value       = aws_instance.worker.public_ip
  sensitive   = false
  description = "public ip of the worker"
}

output "master_private_ip" {
  value       = aws_instance.master.private_ip
  sensitive   = false
  description = "Private IP of the master node"
}

output "worker_private_ip" {
  value       = aws_instance.worker.private_ip
  sensitive   = false
  description = "Private IP of the worker node"
}