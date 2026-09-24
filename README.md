# Real-Time MySQL → Snowflake CDC Pipeline

A cost-conscious CDC practice project that uses **AWS Aurora MySQL, AWS DMS, S3, and Snowflake**, with an optional local **MySQL → Debezium → Kafka** experiment. The source database and related infrastructure have been adapted for MySQL.

## Main AWS Flow
```
Lambda (data generator, every 5 min)
  -> AWS Aurora MySQL Serverless v2
  -> AWS DMS Serverless (full load + CDC)
  -> S3 (Parquet)
  -> Snowflake RAW.CDC_EVENTS   (scheduled Task: COPY INTO)
  -> Snowflake MIRROR.*         (Stream + Task: MERGE, columns _SYNCED_AT / _DELETED)
```

The repository also contains the original local CDC experiment under `debezium-local-test/`, using MySQL, Debezium, Kafka, and Kafka Connect.

## What the project demonstrates

- Aurora MySQL source database
- Full-load + ongoing CDC with AWS DMS
- CDC delivery to Amazon S3 in Parquet format
- Snowflake RAW ingestion
- Snowflake Streams and Tasks
- MERGE-based mirror tables
- INSERT / UPDATE / DELETE demonstration helpers
- Terraform-based AWS infrastructure
- Optional local MySQL + Debezium + Kafka CDC setup

## Repo layout
| Path | What |
|---|---|
| `*.tf` | AWS infrastructure (VPC, Aurora MySQL, S3, DMS, Lambda + Scheduler, budget, IAM) |
| `lambda/package/handler.py` | Replays new/updated orders into Aurora MySQL |
| `data/` | Schema, dummy data generator, loader, demo insert/delete helpers |
| `snowflake/` | Snowflake setup, mirror tables, stream, merge procedure, tasks and checks |
| `debezium-local-test/` | Optional local MySQL + Debezium + Kafka experiment |

## Run order
1. `cp terraform.tfvars.example terraform.tfvars` and fill it in.
2. `pip install -r lambda/requirements.txt -t lambda/package`
3. `terraform init && terraform apply` (DMS and the Lambda schedule stay off).
4. `python data/generate_dummy_data.py --out-dir olist --orders 1500`
5. Set `MYSQL_HOST` and `MYSQL_PASSWORD` (`terraform output`), then `python data/prepare_and_load.py --csv-dir olist --initial-pct 70 --batch-size 50`
6. `aws s3 sync replay_batches s3://<bucket>/replay/`
7. Snowflake: run `snowflake/00_setup.sql`, put the values from `DESC INTEGRATION` into `terraform.tfvars`, and `terraform apply`.
8. Set `start_dms = true` and `replay_enabled = true`, then `terraform apply`.
9. Snowflake: run `01` to `03`, then check with `04_checks.sql`.

## Cost controls
Aurora Serverless v2 at 0.5–2 ACU, DMS Serverless capped at 2 units, an XS Snowflake warehouse with 60-second auto-suspend and a 5-credit resource monitor, plus an AWS Budget alert.

## Teardown
`terraform destroy`, then `snowflake/99_cleanup.sql`.

## Known limitations
No monitoring or failure alerts, but can be added.The delete path is designed but was not fully tested. Not load-tested for high volume.
