data "aws_kms_alias" "ebs_kms" {
  name = var.ebs_kms_id
}

resource "aws_secretsmanager_secret" "panorama_config_secret" {
  name = "${var.name_prefix}-panorama-secret-${random_id.deployment_id.hex}"
}

resource "aws_secretsmanager_secret_version" "panorama_config" {
  secret_id     = aws_secretsmanager_secret.panorama_config_secret.id
  secret_string = jsonencode(var.panorama_config)
}

resource "aws_secretsmanager_secret" "bootstrap_config_secret" {
  name = "${var.name_prefix}-bootstrap-secret-${random_id.deployment_id.hex}"
}

resource "aws_secretsmanager_secret_version" "bootstrap_config" {
  secret_id     = aws_secretsmanager_secret.bootstrap_config_secret.id
  secret_string = jsonencode(var.bootstrap_config)
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE PREREQUISITES FOR FIREWALL
# 1 SSH KEY
# 1 IAM ROLE WITH POLICY
# 1 IAM INSTANCE PROFILE
# ---------------------------------------------------------------------------------------------------------------------

# Config SSH KEY for instance login
resource "aws_key_pair" "fw-ssh-keypair" {
  key_name   = "${var.name_prefix}-ssh-key-${random_id.deployment_id.hex}"
  public_key = var.public_key
}

# Config IAM role with policy
resource "aws_iam_role" "fw-iam-role" {
  name               = "${var.name_prefix}-iam-role-${random_id.deployment_id.hex}"
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
                "*"
            ],
            "Effect": "Allow"
        },
        {
            "Action": [
                "cloudwatch:PutMetricData"
            ],
            "Resource": [
                "*"
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
            "Resource": "arn:aws:logs:*:*:*"
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

resource "aws_launch_template" "fw_asg_launch_tmpl" {
  name          = "${var.name_prefix}-asg-tmpl-${random_id.deployment_id.hex}"
  image_id      = var.firewall_ami_id
  ebs_optimized = true
  instance_type = var.instance_type
  key_name      = aws_key_pair.fw-ssh-keypair.key_name
  user_data              = base64encode("secret_name=${var.name_prefix}-bootstrap-secret-${random_id.deployment_id.hex}\nmgmt-interface-swap=enable\nplugin-op-commands=aws-gwlb-inspect:enable")
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.iam-instance-profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    device_index                = 0
    security_groups             = [aws_security_group.fw_data_sg.id]
    # subnet_id                   = values(var.sec_data_subnet_ids_map)[0]
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

## PAVM: ASG ##

resource "aws_autoscaling_group" "fw_asg" {
  name                      = "${var.name_prefix}-asg-${random_id.deployment_id.hex}"
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 1800
  health_check_type         = "EC2"
  force_delete              = true
  target_group_arns         = [aws_lb_target_group.pa_gwlb_tg.arn]
  vpc_zone_identifier       = [for subnet_az, subnet_id in var.sec_data_subnet_ids_map : subnet_id]

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
    value               = "${var.name_prefix}-pa-vm-${random_id.deployment_id.hex}"
    propagate_at_launch = true
  }
}

# IAM role that will be used for Lambda function
resource "aws_iam_role" "pa_lambda_iam_role" {
  name               = "${var.name_prefix}-lambda-role-${random_id.deployment_id.hex}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Attach IAM policies to IAM role for Lambda
resource "aws_iam_role_policy" "lambda_iam_policy_default" {
  name   = "${var.name_prefix}-lambda-policy-${random_id.deployment_id.hex}"
  role   = aws_iam_role.pa_lambda_iam_role.id
  policy = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Action": [
                "ec2:AllocateAddress",
                "ec2:AssociateAddress",
                "ec2:AttachNetworkInterface",
                "ec2:CreateNetworkInterface",
                "ec2:DescribeAddresses",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeSubnets",
                "ec2:DeleteNetworkInterface",
                "ec2:DetachNetworkInterface",
                "ec2:DisassociateAddress",
                "ec2:ModifyNetworkInterfaceAttribute",
                "ec2:ReleaseAddress",
                "autoscaling:CompleteLifecycleAction",
                "autoscaling:DescribeAutoScalingGroups",
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "kms:GenerateDataKey*",
            "kms:Decrypt",
            "kms:CreateGrant"
          ],
          "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_iam_policy_delicense" {
  count  = var.delicense_enabled ? 1 : 0
  name   = "${var.name_prefix}-lambda-policy-delicense-${random_id.deployment_id.hex}"
  role   = aws_iam_role.pa_lambda_iam_role.id
  policy = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "SecretsManagerRead",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetResourcePolicy",
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:ListSecrets",
                "secretsmanager:ListSecretVersionIds"
            ],
            "Resource": "${aws_secretsmanager_secret.panorama_config_secret.arn}"
        }
    ]
}
EOF
}

# Python external dependencies (e.g. panos libraries) are prepared according to document:
# https://docs.aws.amazon.com/lambda/latest/dg/python-package.html
resource "null_resource" "python_requirements" {
  triggers = {
    installed-pan-os-python = fileexists("${path.module}/scripts/pan_os_python-1.11.0.dist-info/METADATA") || var.lambda_execute_pip_install_once ? true : timestamp()
  }

  provisioner "local-exec" {
    command = "pip install --upgrade --target ${path.module}/scripts -r ${path.module}/scripts/requirements.txt"
  }
}

data "archive_file" "lambda_archive" {
  type = "zip"

  source_dir  = "${path.module}/scripts"
  output_path = "${path.module}/lambda_payload.zip"

  depends_on = [
    null_resource.python_requirements
  ]
}

resource "aws_lambda_function" "pa_lambda" {
  filename                       = data.archive_file.lambda_archive.output_path
  function_name                  = "${var.name_prefix}-asg-actions-${random_id.deployment_id.hex}"
  role                           = aws_iam_role.pa_lambda_iam_role.arn
  handler                        = "lambda.lambda_handler"
  source_code_hash               = data.archive_file.lambda_archive.output_base64sha256
  runtime                        = "python3.8"
  timeout                        = "30"
  reserved_concurrent_executions = "100"

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = [for subnet_az, subnet_id in var.sec_mgmt_subnet_ids_map : subnet_id]
    security_group_ids = [aws_security_group.fw_mgmt_sg.id]
  }

  environment {
    variables = {
      interfaces_config = jsonencode(var.sec_mgmt_subnet_ids_map)
      data_sgr_id       = aws_security_group.fw_mgmt_sg.id
      panorama_config   = aws_secretsmanager_secret.panorama_config_secret.arn
      fw_delicense      = var.delicense_enabled
    }
  }

  depends_on = [data.archive_file.lambda_archive]
}

resource "aws_lambda_permission" "lambda_event_invoke_persmissions" {
  action              = "lambda:InvokeFunction"
  function_name       = aws_lambda_function.pa_lambda.function_name
  principal           = "events.amazonaws.com"
  statement_id_prefix = var.name_prefix
}

resource "aws_cloudwatch_event_rule" "instance_launch_event_rule" {
  name          = "${var.name_prefix}-asg-launch-event-rule-${random_id.deployment_id.hex}"
  event_pattern = <<EOF
{
  "source": [
    "aws.autoscaling"
  ],
  "detail-type": [
    "EC2 Instance-launch Lifecycle Action"
  ],
  "detail": {
    "AutoScalingGroupName": [
      "${var.name_prefix}-asg-${random_id.deployment_id.hex}"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_rule" "instance_terminate_event_rule" {
  name          = "${var.name_prefix}-asg-terminate-event-rule-${random_id.deployment_id.hex}"
  event_pattern = <<EOF
{
  "source": [
    "aws.autoscaling"
  ],
  "detail-type": [
    "EC2 Instance-terminate Lifecycle Action"
  ],
  "detail": {
    "AutoScalingGroupName": [
      "${var.name_prefix}-asg-${random_id.deployment_id.hex}"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "instance_launch_event" {
  rule      = aws_cloudwatch_event_rule.instance_launch_event_rule.name
  target_id = "${var.name_prefix}-asg-launch-${random_id.deployment_id.hex}"
  arn       = aws_lambda_function.pa_lambda.arn
}

resource "aws_cloudwatch_event_target" "instance_terminate_event" {
  rule      = aws_cloudwatch_event_rule.instance_terminate_event_rule.name
  target_id = "${var.name_prefix}-asg-terminate-${random_id.deployment_id.hex}"
  arn       = aws_lambda_function.pa_lambda.arn
}
