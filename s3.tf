data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "raw" {
  bucket        = "${var.project}-raw-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # so `terraform destroy` works even with files inside
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id
  rule {
    id     = "expire-raw"
    status = "Enabled"
    filter {}
    expiration {
      days = 7
    }
  }
}
