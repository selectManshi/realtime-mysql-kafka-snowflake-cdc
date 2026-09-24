variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "project" {
  type    = string
  default = "ecom-pipeline"
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR form (e.g. 203.0.113.10/32) so you can load dummy data from your laptop"
  type        = string
}

variable "db_name" {
  type    = string
  default = "ecommerce"
}

variable "db_username" {
  type    = string
  default = "dbadmin"
}

variable "budget_email" {
  description = "Email for AWS Budget alerts"
  type        = string
}

variable "monthly_budget_usd" {
  type    = number
  default = 50
}

variable "create_dms_vpc_role" {
  description = "Set false if dms-vpc-role already exists in this AWS account"
  type        = bool
  default     = true
}

variable "start_dms" {
  description = "Start DMS replication. Keep false until schema + initial data are loaded, then set true and re-apply."
  type        = bool
  default     = false
}

variable "replay_enabled" {
  description = "Enable the scheduled Lambda that keeps inserting/updating orders. Set true after uploading replay batches to S3."
  type        = bool
  default     = false
}

variable "replay_schedule" {
  type    = string
  default = "rate(5 minutes)"
}
