output "master_public_ip" {
  description = "Public IP of the Kubernetes master node"
  value       = aws_instance.master.public_ip
}

output "master_private_ip" {
  description = "Private IP of the Kubernetes master node"
  value       = aws_instance.master.private_ip
}

output "worker_public_ips" {
  description = "Public IPs of the worker nodes"
  value       = aws_instance.worker[*].public_ip
}

output "worker_private_ips" {
  description = "Private IPs of the worker nodes"
  value       = aws_instance.worker[*].private_ip
}

output "ecr_backend_url" {
  description = "ECR URL for backend image"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_url" {
  description = "ECR URL for frontend image"
  value       = aws_ecr_repository.frontend.repository_url
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "ssh_master_command" {
  description = "SSH command to connect to master"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.master.public_ip}"
}

output "ssh_worker_commands" {
  description = "SSH commands to connect to workers"
  value       = [for w in aws_instance.worker : "ssh -i ~/.ssh/id_rsa ubuntu@${w.public_ip}"]
}

output "next_steps" {
  description = "Next steps after Terraform apply"
  value = <<-EOT
    1. SSH to master:    ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.master.public_ip}
    2. Run bootstrap:    sudo /opt/k8s/bootstrap-master.sh
    3. Copy join cmd:    cat /opt/k8s/join-command.sh
    4. SSH to workers and run join command on each
    5. Verify cluster:   kubectl get nodes
    6. Set ECR URI in GitHub secrets:
       BACKEND_ECR_URL  = ${aws_ecr_repository.backend.repository_url}
       FRONTEND_ECR_URL = ${aws_ecr_repository.frontend.repository_url}
  EOT
}
