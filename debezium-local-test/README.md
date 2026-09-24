# Local MySQL CDC experiment

This optional local experiment uses the included Docker Compose stack to run:

```text
MySQL → Debezium MySQL Connector → Kafka → Kafka Connect
```

The connector registration is in `register-mysql.json`.

Start the stack with:

```bash
docker compose up -d
```

Register the connector through Kafka Connect on port `8083` using the supplied configuration.
