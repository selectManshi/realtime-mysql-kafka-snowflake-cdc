# Scheduled "live traffic" generator: Lambda + EventBridge Scheduler.
# Cost is effectively zero at this volume.

data "archive_file" "replay" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/package"
  output_path = "${path.module}/lambda/replay.zip"
}

resource "aws_security_group" "lambda" {
  name_prefix = "${var.project}-lambda-"
  vpc_id      = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replay" {
  name               = "${var.project}-replay-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "replay_vpc" {
  role       = aws_iam_role.replay.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "replay_s3" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.raw.arn}/replay/*"]
  }
  # ListBucket makes a missing batch return NoSuchKey instead of AccessDenied
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.raw.arn]
  }
}

resource "aws_iam_role_policy" "replay_s3" {
  role   = aws_iam_role.replay.id
  policy = data.aws_iam_policy_document.replay_s3.json
}

resource "aws_lambda_function" "replay" {
  function_name    = "${var.project}-replay"
  role             = aws_iam_role.replay.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.replay.output_path
  source_code_hash = data.archive_file.replay.output_base64sha256
  timeout          = 60
  memory_size      = 256

  vpc_config {
    subnet_ids         = aws_subnet.public[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  # Dummy-data project: creds passed as env vars to avoid a Secrets Manager VPC endpoint (~$7/mo each).
  environment {
    variables = {
      DB_HOST     = aws_rds_cluster.aurora.endpoint
      DB_NAME     = var.db_name
      DB_USER     = var.db_username
      DB_PASSWORD = random_password.db.result
      BUCKET      = aws_s3_bucket.raw.id
    }
  }

  depends_on = [aws_iam_role_policy_attachment.replay_vpc, aws_rds_cluster_instance.writer]
}

# ---- EventBridge Scheduler ----
data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${var.project}-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
}

resource "aws_iam_role_policy" "scheduler" {
  role = aws_iam_role.scheduler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.replay.arn
    }]
  })
}

resource "aws_scheduler_schedule" "replay" {
  name                = "${var.project}-replay"
  schedule_expression = var.replay_schedule
  state               = var.replay_enabled ? "ENABLED" : "DISABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.replay.arn
    role_arn = aws_iam_role.scheduler.arn
  }
}
