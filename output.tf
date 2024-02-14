
output "deployment_id" {
  value = random_id.deployment_id.hex
}

# output "firewall_ip" {
#   value = aws_network_interface.fw-mgmt-eni[*].private_ips
# }

# output "sec_gwlbe_ob_route_table_id" {
#   value = aws_route_table.agwe-rt[*].id
# }

# output "sec_gwlbe_ew_route_table_id" {
#   value = aws_route_table.agwe-ew-rt[*].id
# }

# output "natgw_route_table_id" {
#   value = aws_route_table.natgw-rt[*].id
# }

# output "sec_tgwa_route_table_id" {
#   value = aws_route_table.tgwa-rt[*].id
# }

# output "tgw_id" {
#   value = data.aws_ec2_transit_gateway.panw-tgw.id
# }

# output "tgw_sec_route_table_id" {
#   value = aws_ec2_transit_gateway_route_table.tgw-main-sec-rt.id
# }

# output "tgw_sec_attach_id" {
#   value = aws_ec2_transit_gateway_vpc_attachment.as.id
# }

# output "sec_gwlbe_ob_id" {
#   value = jsondecode(data.local_file.gwlb.content).agwe_id
# }

# output "sec_gwlbe_ew_id" {
#   value = jsondecode(data.local_file.gwlb.content).agwe_ew_id
# }

output "gwlb_arn" {
  value = aws_lb.pa_gwlb.arn
}

output "gwlb_listener_arn" {
  value = aws_lb_listener.pa_gwlb_listener.arn
}

output "gwlb_tg_arn" {
  value = aws_lb_target_group.pa_gwlb_tg.arn
}

output "gwlbe_service_name" {
  value = aws_vpc_endpoint_service.pa_gwlb_vpces.service_name
}

output "gwlbe_service_id" {
  value = aws_vpc_endpoint_service.pa_gwlb_vpces.id
}
