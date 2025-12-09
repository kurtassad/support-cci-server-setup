output "machine_provisioner_subnet_id" {
  description = "Subnet IDs (replace machine_provisioner.providers.ec2.subnets with these)"
  value       = module.vpc.public_subnets
}

output "machine_provisioner_security_group_id" {
  description = "Security group ID for CircleCI machine provisioner (replace machine_provisioner.providers.ec2.securityGroupId with this)"
  value       = aws_security_group.circleci_machine_provisioner.id
}
