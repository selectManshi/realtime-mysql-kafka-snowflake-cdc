-- 02: procedure that merges the CDC stream into the MIRROR tables (soft deletes)
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE ECOM_WH;
USE DATABASE ECOM_DB;

CREATE OR REPLACE PROCEDURE ECOM_DB.MIRROR.SP_MERGE_ALL()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  BEGIN TRANSACTION;

  MERGE INTO ECOM_DB.MIRROR.CUSTOMERS t
  USING (
    SELECT PAYLOAD['customer_id']::STRING AS customer_id,
           PAYLOAD['customer_unique_id']::STRING AS customer_unique_id,
           PAYLOAD['customer_zip_code_prefix']::STRING AS customer_zip_code_prefix,
           PAYLOAD['customer_city']::STRING AS customer_city,
           PAYLOAD['customer_state']::STRING AS customer_state,
           OP AS OP_
    FROM ECOM_DB.RAW.CDC_STREAM
    WHERE SRC_TABLE = 'customers'
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY PAYLOAD['customer_id']::STRING
      ORDER BY TRY_TO_TIMESTAMP_NTZ(PAYLOAD['dms_commit_ts']::STRING) DESC, LOADED_AT DESC) = 1
  ) s ON t.CUSTOMER_ID = s.customer_id
  WHEN MATCHED AND s.OP_ = 'D' THEN UPDATE SET
      t._DELETED = TRUE,
      t._SYNCED_AT = CURRENT_TIMESTAMP()
  WHEN MATCHED THEN UPDATE SET
      t.CUSTOMER_UNIQUE_ID = s.customer_unique_id,
      t.CUSTOMER_ZIP_CODE_PREFIX = s.customer_zip_code_prefix,
      t.CUSTOMER_CITY = s.customer_city,
      t.CUSTOMER_STATE = s.customer_state,
      t._DELETED = FALSE,
      t._SYNCED_AT = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED AND s.OP_ <> 'D' THEN INSERT (CUSTOMER_ID, CUSTOMER_UNIQUE_ID, CUSTOMER_ZIP_CODE_PREFIX, CUSTOMER_CITY, CUSTOMER_STATE, _SYNCED_AT, _DELETED)
      VALUES (s.customer_id, s.customer_unique_id, s.customer_zip_code_prefix, s.customer_city, s.customer_state, CURRENT_TIMESTAMP(), FALSE);

  MERGE INTO ECOM_DB.MIRROR.SELLERS t
  USING (
    SELECT PAYLOAD['seller_id']::STRING AS seller_id,
           PAYLOAD['seller_zip_code_prefix']::STRING AS seller_zip_code_prefix,
           PAYLOAD['seller_city']::STRING AS seller_city,
           PAYLOAD['seller_state']::STRING AS seller_state,
           OP AS OP_
    FROM ECOM_DB.RAW.CDC_STREAM
    WHERE SRC_TABLE = 'sellers'
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY PAYLOAD['seller_id']::STRING
      ORDER BY TRY_TO_TIMESTAMP_NTZ(PAYLOAD['dms_commit_ts']::STRING) DESC, LOADED_AT DESC) = 1
  ) s ON t.SELLER_ID = s.seller_id
  WHEN MATCHED AND s.OP_ = 'D' THEN UPDATE SET
      t._DELETED = TRUE,
      t._SYNCED_AT = CURRENT_TIMESTAMP()
  WHEN MATCHED THEN UPDATE SET
      t.SELLER_ZIP_CODE_PREFIX = s.seller_zip_code_prefix,
      t.SELLER_CITY = s.seller_city,
      t.SELLER_STATE = s.seller_state,
      t._DELETED = FALSE,
      t._SYNCED_AT = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED AND s.OP_ <> 'D' THEN INSERT (SELLER_ID, SELLER_ZIP_CODE_PREFIX, SELLER_CITY, SELLER_STATE, _SYNCED_AT, _DELETED)
      VALUES (s.seller_id, s.seller_zip_code_prefix, s.seller_city, s.seller_state, CURRENT_TIMESTAMP(), FALSE);

  MERGE INTO ECOM_DB.MIRROR.PRODUCTS t
  USING (
    SELECT PAYLOAD['product_id']::STRING AS product_id,
           PAYLOAD['product_category_name']::STRING AS product_category_name,
           PAYLOAD['product_name_lenght']::INT AS product_name_lenght,
           PAYLOAD['product_description_lenght']::INT AS product_description_lenght,
           PAYLOAD['product_photos_qty']::INT AS product_photos_qty,
           PAYLOAD['product_weight_g']::INT AS product_weight_g,
           PAYLOAD['product_length_cm']::INT AS product_length_cm,
           PAYLOAD['product_height_cm']::INT AS product_height_cm,
           PAYLOAD['product_width_cm']::INT AS product_width_cm,
           OP AS OP_
    FROM ECOM_DB.RAW.CDC_STREAM
    WHERE SRC_TABLE = 'products'
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY PAYLOAD['product_id']::STRING
      ORDER BY TRY_TO_TIMESTAMP_NTZ(PAYLOAD['dms_commit_ts']::STRING) DESC, LOADED_AT DESC) = 1
  ) s ON t.PRODUCT_ID = s.product_id
  WHEN MATCHED AND s.OP_ = 'D' THEN UPDATE SET
      t._DELETED = TRUE,
      t._SYNCED_AT = CURRENT_TIMESTAMP()
  WHEN MATCHED THEN UPDATE SET
      t.PRODUCT_CATEGORY_NAME = s.product_category_name,
      t.PRODUCT_NAME_LENGHT = s.product_name_lenght,
      t.PRODUCT_DESCRIPTION_LENGHT = s.product_description_lenght,
      t.PRODUCT_PHOTOS_QTY = s.product_photos_qty,
      t.PRODUCT_WEIGHT_G = s.product_weight_g,
      t.PRODUCT_LENGTH_CM = s.product_length_cm,
      t.PRODUCT_HEIGHT_CM = s.product_height_cm,
      t.PRODUCT_WIDTH_CM = s.product_width_cm,
      t._DELETED = FALSE,
      t._SYNCED_AT = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED AND s.OP_ <> 'D' THEN INSERT (PRODUCT_ID, PRODUCT_CATEGORY_NAME, PRODUCT_NAME_LENGHT, PRODUCT_DESCRIPTION_LENGHT, PRODUCT_PHOTOS_QTY, PRODUCT_WEIGHT_G, PRODUCT_LENGTH_CM, PRODUCT_HEIGHT_CM, PRODUCT_WIDTH_CM, _SYNCED_AT, _DELETED)
      VALUES (s.product_id, s.product_category_name, s.product_name_lenght, s.product_description_lenght, s.product_photos_qty, s.product_weight_g, s.product_length_cm, s.product_height_cm, s.product_width_cm, CURRENT_TIMESTAMP(), FALSE);

  MERGE INTO ECOM_DB.MIRROR.PRODUCT_CATEGORY_NAME_TRANSLATION t
  USING (
    SELECT PAYLOAD['product_category_name']::STRING AS product_category_name,
           PAYLOAD['product_category_name_english']::STRING AS product_category_name_english,
           OP AS OP_
    FROM ECOM_DB.RAW.CDC_STREAM
    WHERE SRC_TABLE = 'product_category_name_translation'
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY PAYLOAD['product_category_name']::STRING
      ORDER BY TRY_TO_TIMESTAMP_NTZ(PAYLOAD['dms_commit_ts']::STRING) DESC, LOADED_AT DESC) = 1
  ) s ON t.PRODUCT_CATEGORY_NAME = s.product_category_name
  WHEN MATCHED AND s.OP_ = 'D' THEN UPDATE SET
      t._DELETED = TRUE,
      t._SYNCED_AT = CURRENT_TIMESTAMP()
  WHEN MATCHED THEN UPDATE SET
      t.PRODUCT_CATEGORY_NAME_ENGLISH = s.product_category_name_english,
      t._DELETED = FALSE,
      t._SYNCED_AT = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED AND s.OP_ <> 'D' THEN INSERT (PRODUCT_CATEGORY_NAME, PRODUCT_CATEGORY_NAME_ENGLISH, _SYNCED_AT, _DELETED)
      VALUES (s.product_category_name, s.product_category_name_english, CURRENT_TIMESTAMP(), FALSE);

  MERGE INTO ECOM_DB.MIRROR.ORDERS t
  USING (
    SELECT PAYLOAD['order_id']::STRING AS order_id,
           PAYLOAD['customer_id']::STRING AS customer_id,
           PAYLOAD['order_status']::STRING AS order_status,
           TRY_TO_TIMESTAMP_NTZ(PAYLOAD['order_purchase_timestamp']::STRING) AS order_purchase_timestamp,
           TRY_TO_TIMESTAMP_NTZ(PAYLOAD['order_approved_at']::STRING) AS order_approved_at,
           TRY_TO_TIMESTAMP_NTZ(PAYLOAD['order_delivered_carrier_date']::STRING) AS order_delivered_carrier_date,
           TRY_TO_TIMESTAMP_NTZ(PAYLOAD['order_delivered_customer_date']::STRING) AS order_delivered_customer_date,
           TRY_TO_TIMESTAMP_NTZ(PAYLOAD['order_estimated_delivery_date']::STRING) AS order_estimated_delivery_date,
           OP AS OP_
    FROM ECOM_DB.RAW.CDC_STREAM
    WHERE SRC_TABLE = 'orders'
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY PAYLOAD['order_id']::STRING
      ORDER BY TRY_TO_TIMESTAMP_NTZ(PAYLOAD['dms_commit_ts']::STRING) DESC, LOADED_AT DESC) = 1
  ) s ON t.ORDER_ID = s.order_id
  WHEN MATCHED AND s.OP_ = 'D' THEN UPDATE SET
      t._DELETED = TRUE,
      t._SYNCED_AT = CURRENT_TIMESTAMP()
  WHEN MATCHED THEN UPDATE SET
      t.CUSTOMER_ID = s.customer_id,
      t.ORDER_STATUS = s.order_status,
      t.ORDER_PURCHASE_TIMESTAMP = s.order_purchase_timestamp,
      t.ORDER_APPROVED_AT = s.order_approved_at,
      t.ORDER_DELIVERED_CARRIER_DATE = s.order_delivered_carrier_date,
      t.ORDER_DELIVERED_CUSTOMER_DATE = s.order_delivered_customer_date,
      t.ORDER_ESTIMATED_DELIVERY_DATE = s.order_estimated_delivery_date,
      t._DELETED = FALSE,
      t._SYNCED_AT = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED AND s.OP_ <> 'D' THEN INSERT (ORDER_ID, CUSTOMER_ID, ORDER_STATUS, ORDER_PURCHASE_TIMESTAMP, ORDER_APPROVED_AT, ORDER_DELIVERED_CARRIER_DATE, ORDER_DELIVERED_CUSTOMER_DATE, ORDER_ESTIMATED_DELIVERY_DATE, _SYNCED_AT, _DELETED)
      VALUES (s.order_id, s.customer_id, s.order_status, s.order_purchase_timestamp, s.order_approved_at, s.order_delivered_carrier_date, s.order_delivered_customer_date, s.order_estimated_delivery_date, CURRENT_TIMESTAMP(), FALSE);

  MERGE INTO ECOM_DB.MIRROR.ORDER_ITEMS t
  USING (
    SELECT PAYLOAD['order_id']::STRING AS order_id,
           PAYLOAD['order_item_id']::INT AS order_item_id,
           PAYLOAD['product_id']::STRING AS product_id,
           PAYLOAD['seller_id']::STRING AS seller_id,
           TRY_TO_TIMESTAMP_NTZ(PAYLOAD['shipping_limit_date']::STRING) AS shipping_limit_date,
           PAYLOAD['price']::NUMBER(10,2) AS price,
           PAYLOAD['freight_value']::NUMBER(10,2) AS freight_value,
           OP AS OP_
    FROM ECOM_DB.RAW.CDC_STREAM
    WHERE SRC_TABLE = 'order_items'
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY PAYLOAD['order_id']::STRING, PAYLOAD['order_item_id']::INT
      ORDER BY TRY_TO_TIMESTAMP_NTZ(PAYLOAD['dms_commit_ts']::STRING) DESC, LOADED_AT DESC) = 1
  ) s ON t.ORDER_ID = s.order_id AND t.ORDER_ITEM_ID = s.order_item_id
  WHEN MATCHED AND s.OP_ = 'D' THEN UPDATE SET
      t._DELETED = TRUE,
      t._SYNCED_AT = CURRENT_TIMESTAMP()
  WHEN MATCHED THEN UPDATE SET
      t.PRODUCT_ID = s.product_id,
      t.SELLER_ID = s.seller_id,
      t.SHIPPING_LIMIT_DATE = s.shipping_limit_date,
      t.PRICE = s.price,
      t.FREIGHT_VALUE = s.freight_value,
      t._DELETED = FALSE,
      t._SYNCED_AT = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED AND s.OP_ <> 'D' THEN INSERT (ORDER_ID, ORDER_ITEM_ID, PRODUCT_ID, SELLER_ID, SHIPPING_LIMIT_DATE, PRICE, FREIGHT_VALUE, _SYNCED_AT, _DELETED)
      VALUES (s.order_id, s.order_item_id, s.product_id, s.seller_id, s.shipping_limit_date, s.price, s.freight_value, CURRENT_TIMESTAMP(), FALSE);

  MERGE INTO ECOM_DB.MIRROR.ORDER_PAYMENTS t
  USING (
    SELECT PAYLOAD['order_id']::STRING AS order_id,
           PAYLOAD['payment_sequential']::INT AS payment_sequential,
           PAYLOAD['payment_type']::STRING AS payment_type,
           PAYLOAD['payment_installments']::INT AS payment_installments,
           PAYLOAD['payment_value']::NUMBER(10,2) AS payment_value,
           OP AS OP_
    FROM ECOM_DB.RAW.CDC_STREAM
    WHERE SRC_TABLE = 'order_payments'
    QUALIFY ROW_NUMBER() OVER (
      PARTITION BY PAYLOAD['order_id']::STRING, PAYLOAD['payment_sequential']::INT
      ORDER BY TRY_TO_TIMESTAMP_NTZ(PAYLOAD['dms_commit_ts']::STRING) DESC, LOADED_AT DESC) = 1
  ) s ON t.ORDER_ID = s.order_id AND t.PAYMENT_SEQUENTIAL = s.payment_sequential
  WHEN MATCHED AND s.OP_ = 'D' THEN UPDATE SET
      t._DELETED = TRUE,
      t._SYNCED_AT = CURRENT_TIMESTAMP()
  WHEN MATCHED THEN UPDATE SET
      t.PAYMENT_TYPE = s.payment_type,
      t.PAYMENT_INSTALLMENTS = s.payment_installments,
      t.PAYMENT_VALUE = s.payment_value,
      t._DELETED = FALSE,
      t._SYNCED_AT = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED AND s.OP_ <> 'D' THEN INSERT (ORDER_ID, PAYMENT_SEQUENTIAL, PAYMENT_TYPE, PAYMENT_INSTALLMENTS, PAYMENT_VALUE, _SYNCED_AT, _DELETED)
      VALUES (s.order_id, s.payment_sequential, s.payment_type, s.payment_installments, s.payment_value, CURRENT_TIMESTAMP(), FALSE);

  COMMIT;
  RETURN 'ok';
EXCEPTION
  WHEN OTHER THEN
    ROLLBACK;
    RAISE;
END;
$$;

-- Run once by hand for the first fill:
-- CALL ECOM_DB.MIRROR.SP_MERGE_ALL();
