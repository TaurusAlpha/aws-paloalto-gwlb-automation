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
