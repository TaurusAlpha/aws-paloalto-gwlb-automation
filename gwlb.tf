data "aws_caller_identity" "pa_caller" {}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE GWLB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_lb" "pa_gwlb" {
  name                             = "${var.name_prefix}-gwlb-${random_id.deployment_id.hex}"
  load_balancer_type               = "gateway"
  subnets                          = [for subnet_az, subnet_id in var.sec_data_subnet_ids_map : subnet_id]
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = false

}

resource "aws_lb_target_group" "pa_gwlb_tg" {
  name        = "${var.name_prefix}-tg-${random_id.deployment_id.hex}"
  protocol    = "GENEVE"
  port        = 6081
  vpc_id      = var.sec_vpc_id
  target_type = "instance"

  health_check {
    protocol = "TCP"
    port     = 80
    enabled  = true
  }
}

resource "aws_lb_listener" "pa_gwlb_listener" {
  load_balancer_arn = aws_lb.pa_gwlb.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pa_gwlb_tg.arn
  }
}

# resource "aws_lb_target_group_attachment" "pa-tg-attachment" {
#   for_each         = aws_instance.firewall_instance
#   target_group_arn = aws_lb_target_group.pa_gwlb_tg.arn
#   target_id        = each.value.id
# }

resource "aws_vpc_endpoint_service" "pa_gwlb_vpces" {
  gateway_load_balancer_arns = [aws_lb.pa_gwlb.arn]
  acceptance_required        = false
  allowed_principals         = ["arn:aws:iam::${data.aws_caller_identity.pa_caller.account_id}:root", "arn:aws:iam::058264066739:root"]
}

resource "aws_vpc_endpoint" "pa_gwlb_vpce" {
  for_each          = var.sec_gwlbe_subnet_ids_map
  service_name      = aws_vpc_endpoint_service.pa_gwlb_vpces.service_name
  subnet_ids        = [each.value]
  vpc_endpoint_type = aws_vpc_endpoint_service.pa_gwlb_vpces.service_type
  vpc_id            = var.sec_vpc_id
  tags = {
    Name = "${var.name_prefix}-vpce-${each.key}-${random_id.deployment_id.hex}"
  }
}

resource "aws_route_table" "pa_gwlb_tgwa_rtb" {
  for_each = aws_vpc_endpoint.pa_gwlb_vpce
  vpc_id   = var.sec_vpc_id
  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = each.value.id
  }
  tags = {
    Name = "${var.name_prefix}-tgwa-rtb-${each.key}-${random_id.deployment_id.hex}"
  }
}

resource "aws_route_table_association" "pa_gwlb_vpce_rtb_association" {
  for_each       = var.sec_tgwa_subnet_ids_map
  subnet_id      = each.value
  route_table_id = aws_route_table.pa_gwlb_tgwa_rtb[each.key].id
}
