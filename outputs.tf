output "aurora_endpoint" {
  value = aws_rds_cluster.aurora.endpoint
}

output "s3_bucket" {
  value = aws_s3_bucket.raw.id
}

output "db_secret_name" {
  value = aws_secretsmanager_secret.db.name
}

output "dms_replication_config_arn" {
  value = aws_dms_replication_config.main.arn
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}

output "replay_lambda" {
  value = aws_lambda_function.replay.function_name
}
