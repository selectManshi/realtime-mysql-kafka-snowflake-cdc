"""One-time prep for the Olist dataset.

1. Creates the schema in Aurora.
2. Bulk-loads reference tables + the first N% of orders (by purchase time).
3. Writes the remaining orders as JSON batches (./replay_batches) that the
   Lambda replays into Aurora on a schedule.

Connection uses these MySQL environment variables:
  MYSQL_HOST, MYSQL_PASSWORD, MYSQL_USER (default dbadmin), MYSQL_DATABASE (default ecommerce)
Run this BEFORE starting the DMS replication.
"""
import argparse
import json
import os
from pathlib import Path

import pandas as pd
import pymysql

FILES = {
    "customers": "olist_customers_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "products": "olist_products_dataset.csv",
    "product_category_name_translation": "product_category_name_translation.csv",
    "orders": "olist_orders_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "order_payments": "olist_order_payments_dataset.csv",
}
PRODUCT_INT_COLS = [
    "product_name_lenght", "product_description_lenght", "product_photos_qty",
    "product_weight_g", "product_length_cm", "product_height_cm", "product_width_cm",
]


def read(csv_dir, table):
    return pd.read_csv(Path(csv_dir) / FILES[table], dtype=str)


def copy_df(cur, table, df):
    cols = list(df.columns)
    placeholders = ", ".join(["%s"] * len(cols))
    sql = f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({placeholders})"
    rows = []
    for row in df.where(pd.notna(df), None).itertuples(index=False, name=None):
        rows.append(tuple(row))
    cur.executemany(sql, rows)
    print(f"  loaded {len(df):>7} rows -> {table}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv-dir", required=True)
    ap.add_argument("--initial-pct", type=int, default=70)
    ap.add_argument("--batch-size", type=int, default=100)
    ap.add_argument("--max-orders", type=int, default=0,
                    help="Practice mode: randomly keep only N orders (and the rows they need). 0 = everything.")
    ap.add_argument("--out-dir", default="replay_batches")
    args = ap.parse_args()

    data = {t: read(args.csv_dir, t) for t in FILES}
    if args.max_orders:
        keep = data["orders"].sample(n=min(args.max_orders, len(data["orders"])), random_state=42)
        ids = set(keep["order_id"])
        data["orders"] = keep
        data["order_items"] = data["order_items"][data["order_items"]["order_id"].isin(ids)]
        data["order_payments"] = data["order_payments"][data["order_payments"]["order_id"].isin(ids)]
        data["customers"] = data["customers"][data["customers"]["customer_id"].isin(set(keep["customer_id"]))]
        data["products"] = data["products"][data["products"]["product_id"].isin(set(data["order_items"]["product_id"]))]
        data["sellers"] = data["sellers"][data["sellers"]["seller_id"].isin(set(data["order_items"]["seller_id"]))]
        print(f"Practice mode: keeping {len(keep)} orders")

    data["products"][PRODUCT_INT_COLS] = data["products"][PRODUCT_INT_COLS].apply(
        lambda s: pd.to_numeric(s).astype("Int64")
    )

    orders = data["orders"].sort_values("order_purchase_timestamp").reset_index(drop=True)
    n_init = int(len(orders) * args.initial_pct / 100)
    init_orders, replay_orders = orders.iloc[:n_init], orders.iloc[n_init:]
    init_ids = set(init_orders["order_id"])

    conn = pymysql.connect(
        host=os.environ["MYSQL_HOST"],
        database=os.environ.get("MYSQL_DATABASE", "ecommerce"),
        user=os.environ.get("MYSQL_USER", "dbadmin"),
        password=os.environ["MYSQL_PASSWORD"],
        ssl={"check_hostname": False},
    )
    with conn, conn.cursor() as cur:
        schema_sql = Path(__file__).with_name("schema.sql").read_text()
        for statement in schema_sql.split(";"):
            statement = statement.strip()
            if statement:
                cur.execute(statement)
        cur.execute("SET FOREIGN_KEY_CHECKS = 0")
        for table in ("order_payments", "order_items", "orders", "products", "sellers", "customers", "product_category_name_translation"):
            cur.execute(f"DELETE FROM {table}")
        cur.execute("SET FOREIGN_KEY_CHECKS = 1")
        cur.execute("UPDATE ops.replay_state SET last_batch = 0 WHERE id = 1")

        print("Initial load:")
        for t in ("customers", "sellers", "products", "product_category_name_translation"):
            copy_df(cur, t, data[t])
        copy_df(cur, "orders", init_orders)
        copy_df(cur, "order_items", data["order_items"][data["order_items"]["order_id"].isin(init_ids)])
        copy_df(cur, "order_payments", data["order_payments"][data["order_payments"]["order_id"].isin(init_ids)])
    conn.close()

    out = Path(args.out_dir)
    out.mkdir(exist_ok=True)
    for old in out.glob("batch_*.json"):
        old.unlink()

    items, pays = data["order_items"], data["order_payments"]
    n_batches = 0
    for i, start in enumerate(range(0, len(replay_orders), args.batch_size), start=1):
        chunk = replay_orders.iloc[start : start + args.batch_size]
        ids = set(chunk["order_id"])
        payload = {
            "orders": json.loads(chunk.to_json(orient="records")),
            "order_items": json.loads(items[items["order_id"].isin(ids)].to_json(orient="records")),
            "order_payments": json.loads(pays[pays["order_id"].isin(ids)].to_json(orient="records")),
        }
        (out / f"batch_{i:05d}.json").write_text(json.dumps(payload))
        n_batches = i
    print(f"Wrote {n_batches} replay batches to {out}/")


if __name__ == "__main__":
    main()
