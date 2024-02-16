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
  allowed_principals         = ["arn:aws:iam::${data.aws_caller_identity.pa_caller.account_id}:root", "arn:aws:iam::058264066739:root"]
}

resource "aws_vpc_endpoint" "pa_gwlb_vpce" {
  for_each          = toset(var.availability_zones)
  service_name      = aws_vpc_endpoint_service.pa_gwlb_vpces.service_name
  subnet_ids        = flatten([for subnet in data.aws_subnet.gwlbe_subnet_data : subnet.id if subnet.availability_zone == each.value])
  vpc_endpoint_type = aws_vpc_endpoint_service.pa_gwlb_vpces.service_type
  vpc_id            = var.vpc_id
  tags = {
    Name = "${var.name_prefix}-vpce-${each.value}-${random_id.deployment_id.hex}"
  }
}

resource "aws_route_table" "pa_gwlb_tgwa_rtb" {
  for_each = toset(var.availability_zones)
  vpc_id   = var.vpc_id
  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.pa_gwlb_vpce[each.value].id
  }
  tags = {
    Name = "${var.name_prefix}-tgwa-rtb-${each.value}-${random_id.deployment_id.hex}"
  }
}

resource "aws_route_table_association" "pa_gwlb_vpce_rtb_association" {
  for_each       = data.aws_subnet.tgwa_subnet_data
  subnet_id      = each.value.id
  route_table_id = aws_route_table.pa_gwlb_tgwa_rtb[each.value.availability_zone].id
}
