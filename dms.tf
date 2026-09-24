# ---- One-time account-level DMS role (skip if it already exists) ----
data "aws_iam_policy_document" "dms_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["dms.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dms_vpc" {
  count              = var.create_dms_vpc_role ? 1 : 0
  name               = "dms-vpc-role"
  assume_role_policy = data.aws_iam_policy_document.dms_assume.json
}

resource "aws_iam_role_policy_attachment" "dms_vpc" {
  count      = var.create_dms_vpc_role ? 1 : 0
  role       = aws_iam_role.dms_vpc[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

# ---- Role DMS uses to write to S3 ----
resource "aws_iam_role" "dms_s3" {
  name               = "${var.project}-dms-s3"
  assume_role_policy = data.aws_iam_policy_document.dms_assume.json
}

data "aws_iam_policy_document" "dms_s3" {
  statement {
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:PutObjectTagging"]
    resources = ["${aws_s3_bucket.raw.arn}/*"]
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.raw.arn]
  }
}

resource "aws_iam_role_policy" "dms_s3" {
  role   = aws_iam_role.dms_s3.id
  policy = data.aws_iam_policy_document.dms_s3.json
}

# ---- Networking + endpoints ----
resource "aws_dms_replication_subnet_group" "main" {
  replication_subnet_group_id          = "${var.project}-dms"
  replication_subnet_group_description = "DMS subnets"
  subnet_ids                           = aws_subnet.public[*].id
  depends_on                           = [aws_iam_role_policy_attachment.dms_vpc]
}

resource "aws_dms_endpoint" "source" {
  endpoint_id   = "${var.project}-aurora-source"
  endpoint_type = "source"
  engine_name   = "aurora"
  server_name   = aws_rds_cluster.aurora.endpoint
  port          = 3306
  database_name = var.db_name
  username      = var.db_username
  password      = random_password.db.result
  ssl_mode      = "require"
}

resource "aws_dms_s3_endpoint" "target" {
  endpoint_id             = "${var.project}-s3-target"
  endpoint_type           = "target"
  bucket_name             = aws_s3_bucket.raw.id
  bucket_folder           = "raw"
  service_access_role_arn = aws_iam_role.dms_s3.arn

  data_format              = "parquet"
  parquet_version          = "parquet-2-0"
  include_op_for_full_load = true
  timestamp_column_name    = "dms_commit_ts"
  cdc_max_batch_interval   = 60 # seconds; raise to 300+ to cut cost further

  depends_on = [aws_iam_role_policy.dms_s3]
}

# ---- DMS Serverless: full load + ongoing CDC ----
resource "aws_dms_replication_config" "main" {
  replication_config_identifier = "${var.project}-aurora-to-s3"
  replication_type              = "full-load-and-cdc"
  source_endpoint_arn           = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn           = aws_dms_s3_endpoint.target.endpoint_arn
  start_replication             = var.start_dms

  compute_config {
    replication_subnet_group_id  = aws_dms_replication_subnet_group.main.replication_subnet_group_id
    vpc_security_group_ids       = [aws_security_group.dms.id]
    min_capacity_units           = 1
    max_capacity_units           = 2
    multi_az                     = false
  }

  table_mappings = jsonencode({
    rules = [{
      "rule-type"      = "selection"
      "rule-id"        = "1"
      "rule-name"      = "include-public"
      "object-locator" = { "schema-name" = var.db_name, "table-name" = "%" }
      "rule-action"    = "include"
    }]
  })
}
