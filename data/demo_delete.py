"""Deletes the newest demo order (and its items/payments) from Aurora,
to show how a source-side DELETE arrives in Snowflake (_DELETED = TRUE).
Connection: MYSQL_HOST, MYSQL_PASSWORD (MYSQL_USER default dbadmin, MYSQL_DATABASE default ecommerce)
"""
import os

import pymysql

conn = pymysql.connect(
    host=os.environ["MYSQL_HOST"],
    database=os.environ.get("MYSQL_DATABASE", "ecommerce"),
    user=os.environ.get("MYSQL_USER", "dbadmin"),
    password=os.environ["MYSQL_PASSWORD"],
    ssl={"check_hostname": False},
)
with conn, conn.cursor() as cur:
    cur.execute(
        "SELECT order_id FROM orders WHERE order_id LIKE 'demo%' "
        "ORDER BY order_purchase_timestamp DESC, order_id LIMIT 1"
    )
    row = cur.fetchone()
    if not row:
        print("No demo orders found")
    else:
        oid = row[0]
        cur.execute("DELETE FROM order_payments WHERE order_id = %s", (oid,))
        cur.execute("DELETE FROM order_items WHERE order_id = %s", (oid,))
        cur.execute("DELETE FROM orders WHERE order_id = %s", (oid,))
        print("Deleted order", oid)
