CREATE DATABASE IF NOT EXISTS ops;

CREATE TABLE IF NOT EXISTS ops.replay_state (
  id         SMALLINT PRIMARY KEY,
  last_batch INTEGER NOT NULL DEFAULT 0
);
INSERT IGNORE INTO ops.replay_state (id, last_batch) VALUES (1, 0);

CREATE TABLE IF NOT EXISTS customers (
  customer_id              VARCHAR(255) PRIMARY KEY,
  customer_unique_id       VARCHAR(255),
  customer_zip_code_prefix VARCHAR(255),
  customer_city            VARCHAR(255),
  customer_state           VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS sellers (
  seller_id              VARCHAR(255) PRIMARY KEY,
  seller_zip_code_prefix VARCHAR(255),
  seller_city            VARCHAR(255),
  seller_state           VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS products (
  product_id                 VARCHAR(255) PRIMARY KEY,
  product_category_name      VARCHAR(255),
  product_name_lenght        INTEGER,
  product_description_lenght INTEGER,
  product_photos_qty         INTEGER,
  product_weight_g           INTEGER,
  product_length_cm          INTEGER,
  product_height_cm          INTEGER,
  product_width_cm           INTEGER
);

CREATE TABLE IF NOT EXISTS product_category_name_translation (
  product_category_name         VARCHAR(255) PRIMARY KEY,
  product_category_name_english VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS orders (
  order_id                      VARCHAR(255) PRIMARY KEY,
  customer_id                   VARCHAR(255) NOT NULL,
  order_status                  VARCHAR(255),
  order_purchase_timestamp      TIMESTAMP,
  order_approved_at             TIMESTAMP,
  order_delivered_carrier_date  TIMESTAMP,
  order_delivered_customer_date TIMESTAMP,
  order_estimated_delivery_date TIMESTAMP,
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

CREATE TABLE IF NOT EXISTS order_items (
  order_id            VARCHAR(255) NOT NULL,
  order_item_id       INTEGER NOT NULL,
  product_id          VARCHAR(255),
  seller_id           VARCHAR(255),
  shipping_limit_date TIMESTAMP,
  price               DECIMAL(10,2),
  freight_value       DECIMAL(10,2),
  PRIMARY KEY (order_id, order_item_id),
  FOREIGN KEY (order_id) REFERENCES orders (order_id),
  FOREIGN KEY (product_id) REFERENCES products (product_id),
  FOREIGN KEY (seller_id) REFERENCES sellers (seller_id)
);

CREATE TABLE IF NOT EXISTS order_payments (
  order_id             VARCHAR(255) NOT NULL,
  payment_sequential   INTEGER NOT NULL,
  payment_type         VARCHAR(255),
  payment_installments INTEGER,
  payment_value        DECIMAL(10,2),
  PRIMARY KEY (order_id, payment_sequential),
  FOREIGN KEY (order_id) REFERENCES orders (order_id)
);
