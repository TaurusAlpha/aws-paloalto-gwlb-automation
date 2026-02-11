output "asg_instance_profile_name" {
  value       = aws_iam_instance_profile.iam-instance-profile.name
  description = "Name of the IAM instance profile used by the ASG."
}

output "asg_security_group_id" {
  value       = aws_security_group.fw_data_sg.id
  description = "Security group ID for the ASG data interface."
}

output "asg_launch_template_id" {
  value       = aws_launch_template.fw_asg_launch_tmpl.id
  description = "ID of the launch template used by the ASG."
}

output "gwlbe_service_name" {
  value = aws_vpc_endpoint_service.pa_gwlb_vpces.service_name
}

output "panorama_config_secret" {
  value = aws_secretsmanager_secret.panorama_config_secret.name
}

output "bootstrap_config_secret" {
  value = aws_secretsmanager_secret.bootstrap_config_secret.name
}

output "deployment_id_suffix" {
  value = random_id.deployment_id.hex
}
