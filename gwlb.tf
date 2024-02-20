# ---------------------------------------------------------------------------------------------------------------------
# CREATE GWLB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_lb" "pa_gwlb" {
  name                             = "${var.name_prefix}-gwlb-${random_id.deployment_id.hex}"
  load_balancer_type               = "gateway"
  subnets                          = var.data_subnets
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = false

}

resource "aws_lb_target_group" "pa_gwlb_tg" {
  name        = "${var.name_prefix}-tg-${random_id.deployment_id.hex}"
  protocol    = "GENEVE"
  port        = 6081
  vpc_id      = var.vpc_id
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

resource "aws_vpc_endpoint_service" "pa_gwlb_vpces" {
  gateway_load_balancer_arns = [aws_lb.pa_gwlb.arn]
  acceptance_required        = false
  allowed_principals         = [
    "arn:aws:iam::${data.aws_caller_identity.pa_caller.account_id}:root",
    # todo: remove hardcoded account id
    "arn:aws:iam::058264066739:root"
  ]
}

resource "aws_vpc_endpoint" "pa_gwlb_vpce" {
  for_each     = toset(var.availability_zone_ids)
  service_name = aws_vpc_endpoint_service.pa_gwlb_vpces.service_name
  subnet_ids   = flatten([
    for subnet in data.aws_subnet.gwlbe_subnet_data : subnet.id if subnet.availability_zone_id == each.value
  ])
  vpc_endpoint_type = aws_vpc_endpoint_service.pa_gwlb_vpces.service_type
  vpc_id            = var.vpc_id
  tags              = {
    Name = "${var.name_prefix}-vpce-${each.value}-${random_id.deployment_id.hex}"
  }
}
#
resource "aws_route" "tgwlbe" {
  for_each = toset(var.availability_zone_ids)

  route_table_id         = var.tgwa_route_tables[index(var.availability_zone_ids, each.key)]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = aws_vpc_endpoint.pa_gwlb_vpce[each.value].id
}
