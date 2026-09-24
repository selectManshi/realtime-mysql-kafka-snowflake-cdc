resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project}-aurora-credentials"
  recovery_window_in_days = 0 # delete immediately on destroy
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    host     = aws_rds_cluster.aurora.endpoint
    port     = 3306
    dbname   = var.db_name
  })
}

resource "aws_db_subnet_group" "aurora" {
  name       = "${var.project}-aurora"
  subnet_ids = aws_subnet.public[*].id
}

# Aurora MySQL binlog settings required for ongoing CDC.
resource "aws_rds_cluster_parameter_group" "aurora" {
  name   = "${var.project}-aurora-mysql80"
  family = "aurora-mysql8.0"

  parameter {
    name         = "binlog_format"
    value        = "ROW"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "binlog_row_image"
    value        = "FULL"
    apply_method = "pending-reboot"
  }
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier              = "${var.project}-aurora"
  engine                          = "aurora-mysql"
  engine_version                  = "8.0.mysql_aurora.3.08.2"
  database_name                   = var.db_name
  master_username                 = var.db_username
  master_password                 = random_password.db.result
  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name
  storage_encrypted               = true

  # Easy teardown
  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 2
  }
}

resource "aws_rds_cluster_instance" "writer" {
  identifier          = "${var.project}-aurora-writer"
  cluster_identifier  = aws_rds_cluster.aurora.id
  instance_class      = "db.serverless"
  engine              = aws_rds_cluster.aurora.engine
  engine_version      = aws_rds_cluster.aurora.engine_version
  publicly_accessible = true
}
