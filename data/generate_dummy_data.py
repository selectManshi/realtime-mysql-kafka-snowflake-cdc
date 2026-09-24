"""Generates a small dummy e-commerce dataset (no downloads, no extra libraries).

Writes CSVs with the SAME names/columns as the Olist dataset, so
prepare_and_load.py works on them unchanged.

Usage:  python data\\generate_dummy_data.py --out-dir olist --orders 1500
"""
import argparse
import csv
import random
import uuid
from datetime import datetime, timedelta
from pathlib import Path

CITIES = [("sao paulo", "SP"), ("rio de janeiro", "RJ"), ("belo horizonte", "MG"),
          ("curitiba", "PR"), ("salvador", "BA"), ("porto alegre", "RS")]
CATEGORIES = [("cama_mesa_banho", "bed_bath_table"), ("beleza_saude", "health_beauty"),
              ("esporte_lazer", "sports_leisure"), ("informatica_acessorios", "computers_accessories"),
              ("moveis_decoracao", "furniture_decor"), ("brinquedos", "toys")]
STATUSES = ["delivered"] * 80 + ["shipped"] * 8 + ["approved"] * 5 + ["canceled"] * 4 + ["invoiced"] * 3
PAY_TYPES = ["credit_card"] * 7 + ["boleto"] * 2 + ["voucher", "debit_card"]


def uid():
    return uuid.uuid4().hex


def ts(d):
    return d.strftime("%Y-%m-%d %H:%M:%S") if d else ""


def write(path, header, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"  {path.name}: {len(rows)} rows")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default="olist")
    ap.add_argument("--orders", type=int, default=1500)
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()
    random.seed(args.seed)
    out = Path(args.out_dir)
    out.mkdir(exist_ok=True)

    n_cust, n_sell, n_prod = max(args.orders // 3, 50), 40, 120

    customers = []
    for _ in range(n_cust):
        city, st = random.choice(CITIES)
        customers.append([uid(), uid(), str(random.randint(1000, 99999)), city, st])
    sellers = []
    for _ in range(n_sell):
        city, st = random.choice(CITIES)
        sellers.append([uid(), str(random.randint(1000, 99999)), city, st])
    products = [[uid(), random.choice(CATEGORIES)[0], random.randint(20, 60),
                 random.randint(100, 1500), random.randint(1, 6), random.randint(100, 5000),
                 random.randint(10, 60), random.randint(5, 40), random.randint(10, 50)]
                for _ in range(n_prod)]
    translation = [list(c) for c in CATEGORIES]

    now = datetime.now().replace(microsecond=0)
    orders, items, payments = [], [], []
    for _ in range(args.orders):
        oid = uid()
        cust = random.choice(customers)[0]
        status = random.choice(STATUSES)
        purchase = now - timedelta(minutes=random.randint(60, 60 * 24 * 60))
        approved = None if status == "canceled" else purchase + timedelta(minutes=random.randint(5, 120))
        carrier = delivered = None
        if status in ("shipped", "delivered"):
            carrier = purchase + timedelta(days=random.randint(1, 3))
        if status == "delivered":
            delivered = carrier + timedelta(days=random.randint(2, 8))
        estimated = purchase + timedelta(days=random.randint(10, 25))
        orders.append([oid, cust, status, ts(purchase), ts(approved), ts(carrier), ts(delivered), ts(estimated)])

        total = 0.0
        for i in range(1, random.choice([1, 1, 1, 2, 3]) + 1):
            price = round(random.uniform(9, 400), 2)
            freight = round(random.uniform(5, 40), 2)
            total += price + freight
            items.append([oid, i, random.choice(products)[0], random.choice(sellers)[0],
                          ts(purchase + timedelta(days=3)), price, freight])
        ptype = random.choice(PAY_TYPES)
        payments.append([oid, 1, ptype, random.randint(1, 6) if ptype == "credit_card" else 1, round(total, 2)])

    print("Generated:")
    write(out / "olist_customers_dataset.csv",
          ["customer_id", "customer_unique_id", "customer_zip_code_prefix", "customer_city", "customer_state"], customers)
    write(out / "olist_sellers_dataset.csv",
          ["seller_id", "seller_zip_code_prefix", "seller_city", "seller_state"], sellers)
    write(out / "olist_products_dataset.csv",
          ["product_id", "product_category_name", "product_name_lenght", "product_description_lenght",
           "product_photos_qty", "product_weight_g", "product_length_cm", "product_height_cm",
           "product_width_cm"], products)
    write(out / "product_category_name_translation.csv",
          ["product_category_name", "product_category_name_english"], translation)
    write(out / "olist_orders_dataset.csv",
          ["order_id", "customer_id", "order_status", "order_purchase_timestamp", "order_approved_at",
           "order_delivered_carrier_date", "order_delivered_customer_date", "order_estimated_delivery_date"], orders)
    write(out / "olist_order_items_dataset.csv",
          ["order_id", "order_item_id", "product_id", "seller_id", "shipping_limit_date", "price",
           "freight_value"], items)
    write(out / "olist_order_payments_dataset.csv",
          ["order_id", "payment_sequential", "payment_type", "payment_installments", "payment_value"], payments)


if __name__ == "__main__":
    main()
