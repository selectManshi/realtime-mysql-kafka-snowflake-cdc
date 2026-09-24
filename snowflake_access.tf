# Lets Snowflake read the raw S3 files (Storage Integration pattern).
# Step 1: run the CREATE STORAGE INTEGRATION SQL in Snowflake (role name below is fixed in advance).
# Step 2: copy STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID from DESC INTEGRATION
#         into terraform.tfvars and apply -> this creates the role.

variable "snowflake_iam_user_arn" {
  description = "STORAGE_AWS_IAM_USER_ARN from DESC INTEGRATION (leave empty until you have it)"
  type        = string
  default     = ""
}

variable "snowflake_external_id" {
  description = "STORAGE_AWS_EXTERNAL_ID from DESC INTEGRATION"
  type        = string
  default     = ""
}

locals {
  snowflake_role_name   = "${var.project}-snowflake-s3"
  create_snowflake_role = var.snowflake_iam_user_arn != "" && var.snowflake_external_id != ""
}

resource "aws_iam_role" "snowflake" {
  count = local.create_snowflake_role ? 1 : 0
  name  = local.snowflake_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = var.snowflake_iam_user_arn }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "sts:ExternalId" = var.snowflake_external_id } }
    }]
  })
}

resource "aws_iam_role_policy" "snowflake" {
  count = local.create_snowflake_role ? 1 : 0
  role  = aws_iam_role.snowflake[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${aws_s3_bucket.raw.arn}/raw/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.raw.arn
      }
    ]
  })
}

output "snowflake_role_arn" {
  value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.snowflake_role_name}"
}
