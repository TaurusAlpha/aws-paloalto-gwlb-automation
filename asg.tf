# ---------------------------------------------------------------------------------------------------------------------
# CREATE SECRET WITH PA BOOTSTRAP DATA
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "bootstrap_config_secret" {
  name = "${var.name_prefix}-secret-bootstrap-${random_id.deployment_id.hex}"
}

resource "aws_secretsmanager_secret_version" "bootstrap_config" {
  secret_id     = aws_secretsmanager_secret.bootstrap_config_secret.id
  secret_string = jsonencode(var.bootstrap_config)
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE PREREQUISITES FOR FIREWALL
# 1 SSH KEY IF PUBLIC_KEY SPECIFIED
# 1 IAM ROLE WITH POLICY
# 1 IAM INSTANCE PROFILE
# ---------------------------------------------------------------------------------------------------------------------

# Config SSH KEY for instance login
resource "aws_key_pair" "fw-ssh-keypair" {
  count      = var.public_key == "" ? 0 : 1
  key_name   = "${var.name_prefix}-ssh-key-${random_id.deployment_id.hex}"
  public_key = var.public_key
}

resource "aws_iam_role" "fw-iam-role" {
  name               = "${var.name_prefix}-iam-instance-role-${random_id.deployment_id.hex}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "fw-iam-policy" {
  name        = "${var.name_prefix}-iam-policy-${random_id.deployment_id.hex}"
  path        = "/"
  description = "IAM Policy for VM-Series Firewall"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:AttachNetworkInterface",
        "ec2:DetachNetworkInterface",
        "ec2:DescribeInstances",
        "ec2:DescribeNetworkInterfaces"
      ],
      "Resource": [
        "arn:aws:ec2:${var.region}:${data.aws_caller_identity.pa_caller.account_id}:instance/*",
        "arn:aws:ec2:${var.region}:${data.aws_caller_identity.pa_caller.account_id}:network-interface/*"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Resource": [
        "arn:aws:cloudwatch:${var.region}:${data.aws_caller_identity.pa_caller.account_id}:*"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecrets",
        "secretsmanager:ListSecretVersionIds"
      ],
      "Resource": "${aws_secretsmanager_secret.bootstrap_config_secret.arn}",
      "Effect": "Allow"
    },
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:logs:${var.region}:${data.aws_caller_identity.pa_caller.account_id}:*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "policy-attachment" {
  role       = aws_iam_role.fw-iam-role.name
  policy_arn = aws_iam_policy.fw-iam-policy.arn
}

resource "aws_iam_instance_profile" "iam-instance-profile" {
  name = "${var.name_prefix}-iam-profile-${random_id.deployment_id.hex}"
  role = aws_iam_role.fw-iam-role.name
}

# Create Launch Template for the ASG
resource "aws_launch_template" "fw_asg_launch_tmpl" {
  name          = "${var.name_prefix}-asg-tmpl-${random_id.deployment_id.hex}"
  image_id      = coalesce(var.vmseries_ami_id, try(data.aws_ami.ami_id[0].id, null))
  ebs_optimized = true
  instance_type = var.instance_type
  key_name      = coalesce(try(aws_key_pair.fw-ssh-keypair[0].key_name, null), var.ssh_key_pair)
  user_data     = base64encode("mgmt-interface-swap=enable\nplugin-op-commands=aws-gwlb-inspect:enable\nsecret_name=${var.name_prefix}-secret-bootstrap-${random_id.deployment_id.hex}\n")
  iam_instance_profile {
    name = aws_iam_instance_profile.iam-instance-profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    device_index                = 0
    security_groups             = [aws_security_group.fw_data_sg.id]

    # subnet_id can be ignored due to ASG vpc_zone_identifier mapping
    # subnet_id                   = element(var.data_subnets, 0)
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      # volume_type           = "gp3"
      encrypted  = true
      kms_key_id = data.aws_kms_alias.ebs_kms.arn
    }
  }
}

# Create ASG
resource "aws_autoscaling_group" "fw_asg" {
  name                      = "${var.name_prefix}-asg-${random_id.deployment_id.hex}"
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 1200
  health_check_type         = "EC2"
  force_delete              = true
  target_group_arns         = [aws_lb_target_group.pa_gwlb_tg.arn]
  vpc_zone_identifier       = var.data_subnets

  initial_lifecycle_hook {
    name                 = "${var.name_prefix}-asg-launch-hook-${random_id.deployment_id.hex}"
    default_result       = "CONTINUE"
    heartbeat_timeout    = var.lifecycle_hook_timeout
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  }

  initial_lifecycle_hook {
    name                 = "${var.name_prefix}-asg-terminate-hook-${random_id.deployment_id.hex}"
    default_result       = "CONTINUE"
    heartbeat_timeout    = var.lifecycle_hook_timeout
    lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
  }

  launch_template {
    id      = aws_launch_template.fw_asg_launch_tmpl.id
    version = "$Default"
  }

  timeouts {
    delete = var.global_asg_timeout
  }

  suspended_processes       = var.suspended_processes
  wait_for_capacity_timeout = var.global_asg_timeout

  depends_on = [
    aws_cloudwatch_event_target.instance_launch_event,
    aws_cloudwatch_event_target.instance_terminate_event
  ]

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-${random_id.deployment_id.hex}"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.default_tag
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
