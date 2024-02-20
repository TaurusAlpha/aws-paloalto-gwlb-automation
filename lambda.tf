resource "aws_secretsmanager_secret" "panorama_config_secret" {
  name = "${var.name_prefix}-secret-panorama-${random_id.deployment_id.hex}"
}

resource "aws_secretsmanager_secret_version" "panorama_config" {
  secret_id     = aws_secretsmanager_secret.panorama_config_secret.id
  secret_string = jsonencode(var.panorama_config)
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.name_prefix}-asg-actions-${random_id.deployment_id.hex}"
  skip_destroy      = false
  retention_in_days = 30
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
  name   = "${var.name_prefix}-lambda-instance-policy-${random_id.deployment_id.hex}"
  role   = aws_iam_role.pa_lambda_iam_role.id
  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "${aws_cloudwatch_log_group.lambda_log_group.arn}:*"
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
        "autoscaling:DescribeAutoScalingGroups"
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
    command = "pip3 install --upgrade --target ${path.module}/scripts -r ${path.module}/scripts/requirements.txt"
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
    subnet_ids         = var.mgmt_subnets
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      interfaces_config = jsonencode({ for subnet in data.aws_subnet.mgmt_subnet_data : subnet.availability_zone => subnet.id })
      sgr_id            = aws_security_group.fw_mgmt_sg.id
      panorama_config   = aws_secretsmanager_secret.panorama_config_secret.arn
      fw_delicense      = var.delicense_enabled
    }
  }

  depends_on = [data.archive_file.lambda_archive, aws_cloudwatch_log_group.lambda_log_group]
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
