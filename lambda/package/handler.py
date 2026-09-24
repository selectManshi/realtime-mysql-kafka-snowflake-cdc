"""Replays the next batch of Olist orders into Aurora.

Each run:
  * INSERTs batch N (orders come in as 'processing')
  * UPDATEs batch N-1 orders to their real final status
so DMS captures both INSERT and UPDATE events. Progress is tracked in
ops.replay_state (a different schema, so DMS does not replicate it).
"""
import json
import os
import boto3
import pymysql
from botocore.exceptions import ClientError

s3 = boto3.client("s3")
BUCKET = os.environ["BUCKET"]

COLS = {
    "orders": [
        ("order_id", "text"),
        ("customer_id", "text"),
        ("order_status", "text"),
        ("order_purchase_timestamp", "timestamp"),
        ("order_approved_at", "timestamp"),
        ("order_delivered_carrier_date", "timestamp"),
        ("order_delivered_customer_date", "timestamp"),
        ("order_estimated_delivery_date", "timestamp"),
    ],
    "order_items": [
        ("order_id", "text"),
        ("order_item_id", "integer"),
        ("product_id", "text"),
        ("seller_id", "text"),
        ("shipping_limit_date", "timestamp"),
        ("price", "numeric"),
        ("freight_value", "numeric"),
    ],
    "order_payments": [
        ("order_id", "text"),
        ("payment_sequential", "integer"),
        ("payment_type", "text"),
        ("payment_installments", "integer"),
        ("payment_value", "numeric"),
    ],
}


def _connect():
    # Dummy-data project: encrypted but certificate not verified.
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return pymysql.connect(
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        host=os.environ["DB_HOST"],
        port=3306,
        database=os.environ["DB_NAME"],
        ssl={"check_hostname": False},
        connect_timeout=30,
    )


def _load_batch(n):
    key = f"replay/batch_{n:05d}.json"
    try:
        body = s3.get_object(Bucket=BUCKET, Key=key)["Body"].read()
    except ClientError as e:
        if e.response["Error"]["Code"] in ("NoSuchKey", "404"):
            return None
        raise
    return json.loads(body)


def _insert(conn, table, rows):
    cols = COLS[table]
    names = ", ".join(c for c, _ in cols)
    placeholders = ", ".join(["%s"] * len(cols))
    sql = f"INSERT INTO {table} ({names}) VALUES ({placeholders}) ON DUPLICATE KEY UPDATE order_id=order_id "
    for r in rows:
        with conn.cursor() as cur:
            cur.execute(sql, tuple(r.get(c) for c, _ in cols))



def handler(event, context):
    conn = _connect()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT last_batch FROM ops.replay_state WHERE id = 1")
            last = cur.fetchone()[0]
        batch = _load_batch(last + 1)
        if batch is None:
            return {"status": "no_more_batches", "last_batch": last}
        prev = _load_batch(last) if last > 0 else None

        conn.begin()
        try:
            new_orders = [
                {
                    **o,
                    "order_status": "processing",
                    "order_delivered_carrier_date": None,
                    "order_delivered_customer_date": None,
                }
                for o in batch["orders"]
            ]
            _insert(conn, "orders", new_orders)
            _insert(conn, "order_items", batch["order_items"])
            _insert(conn, "order_payments", batch["order_payments"])

            if prev:
                for o in prev["orders"]:
                    with conn.cursor() as cur:
                        cur.execute(
                            """UPDATE orders SET
                            order_status = %s,
                            order_approved_at = %s,
                            order_delivered_carrier_date = %s,
                            order_delivered_customer_date = %s
                            WHERE order_id = %s""",
                            (o.get("order_status"), o.get("order_approved_at"),
                             o.get("order_delivered_carrier_date"), o.get("order_delivered_customer_date"),
                             o["order_id"]),
                        )
            with conn.cursor() as cur:
                cur.execute("UPDATE ops.replay_state SET last_batch = %s WHERE id = 1", (last + 1,))
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        return {"status": "ok", "batch": last + 1}
    finally:
        conn.close()
