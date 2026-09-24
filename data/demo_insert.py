"""Live-demo helper: adds a few new orders to Aurora (INSERTs), or marks them
delivered (UPDATE), so you can show the change arriving in Snowflake.

  python data\\demo_insert.py --count 3     -> 3 new orders, status 'approved'
  python data\\demo_insert.py --deliver     -> all demo orders become 'delivered'

Demo orders have order_id starting with 'demo'.
Connection: MYSQL_HOST, MYSQL_PASSWORD (MYSQL_USER default dbadmin, MYSQL_DATABASE default ecommerce)
"""
import argparse
import os
import random
import uuid
from datetime import datetime, timedelta

import pymysql


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=3)
    ap.add_argument("--deliver", action="store_true")
    args = ap.parse_args()

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        database=os.environ.get("MYSQL_DATABASE", "ecommerce"),
        user=os.environ.get("MYSQL_USER", "dbadmin"),
        password=os.environ["MYSQL_PASSWORD"],
        ssl={"check_hostname": False},
    )
    now = datetime.now().replace(microsecond=0)

    with conn, conn.cursor() as cur:
        if args.deliver:
            cur.execute(
                "UPDATE orders SET order_status = 'delivered', "
                "order_delivered_carrier_date = %s, order_delivered_customer_date = %s "
                "WHERE order_id LIKE 'demo%' AND order_status <> 'delivered'",
                (now, now),
            )
            print(f"Marked {cur.rowcount} demo order(s) as delivered")
            return

        cur.execute("SELECT customer_id FROM customers ORDER BY RAND() LIMIT 50")
        customers = [r[0] for r in cur.fetchall()]
        cur.execute("SELECT product_id FROM products ORDER BY RAND() LIMIT 50")
        products = [r[0] for r in cur.fetchall()]
        cur.execute("SELECT seller_id FROM sellers")
        sellers = [r[0] for r in cur.fetchall()]

        for _ in range(args.count):
            oid = "demo" + uuid.uuid4().hex[:28]
            cur.execute(
                "INSERT INTO orders (order_id, customer_id, order_status, order_purchase_timestamp, "
                "order_approved_at, order_estimated_delivery_date) VALUES (%s, %s, 'approved', %s, %s, %s)",
                (oid, random.choice(customers), now, now, now + timedelta(days=10)),
            )
            total = 0.0
            for i in range(1, random.choice([1, 2]) + 1):
                price = round(random.uniform(20, 300), 2)
                freight = round(random.uniform(5, 30), 2)
                total += price + freight
                cur.execute(
                    "INSERT INTO order_items (order_id, order_item_id, product_id, seller_id, "
                    "shipping_limit_date, price, freight_value) VALUES (%s, %s, %s, %s, %s, %s, %s)",
                    (oid, i, random.choice(products), random.choice(sellers), now + timedelta(days=3), price, freight),
                )
            cur.execute(
                "INSERT INTO order_payments (order_id, payment_sequential, payment_type, "
                "payment_installments, payment_value) VALUES (%s, 1, 'credit_card', 1, %s)",
                (oid, round(total, 2)),
            )
            print("Inserted order", oid)


if __name__ == "__main__":
    main()
