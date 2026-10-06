/* 03_core_views.sql – cleaned and typed views on top of the raw staging tables.
   Rule: never change stg; all cleaning happens here so it is transparent and repeatable. */
USE olist;
GO

CREATE OR ALTER VIEW core.orders AS
SELECT
    order_id,
    customer_id,
    LOWER(LTRIM(RTRIM(order_status)))                                   AS order_status,
    TRY_CONVERT(datetime2(0), order_purchase_timestamp, 120)            AS purchase_ts,
    TRY_CONVERT(datetime2(0), order_approved_at, 120)                   AS approved_ts,
    TRY_CONVERT(datetime2(0), order_delivered_carrier_date, 120)        AS delivered_carrier_ts,
    TRY_CONVERT(datetime2(0), order_delivered_customer_date, 120)       AS delivered_customer_ts,
    TRY_CONVERT(date, LEFT(order_estimated_delivery_date, 10), 23)      AS estimated_delivery_date
FROM stg.orders;
GO

CREATE OR ALTER VIEW core.order_items AS
SELECT
    order_id,
    TRY_CONVERT(int, order_item_id)                             AS order_item_id,
    product_id,
    seller_id,
    TRY_CONVERT(datetime2(0), shipping_limit_date, 120)         AS shipping_limit_ts,
    TRY_CONVERT(decimal(12, 2), price)                          AS price_brl,
    TRY_CONVERT(decimal(12, 2), freight_value)                  AS freight_brl
FROM stg.order_items;
GO

CREATE OR ALTER VIEW core.customers AS
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix AS zip_prefix,
    customer_city            AS city,
    UPPER(customer_state)    AS state
FROM stg.customers;
GO

CREATE OR ALTER VIEW core.sellers AS
SELECT
    seller_id,
    seller_zip_code_prefix AS zip_prefix,
    seller_city            AS city,
    UPPER(seller_state)    AS state
FROM stg.sellers;
GO

CREATE OR ALTER VIEW core.products AS
SELECT
    p.product_id,
    COALESCE(
        t.product_category_name_english,
        CASE p.product_category_name                  -- 2 categories are missing in the translation file
            WHEN 'pc_gamer' THEN 'pc_gamer'
            WHEN 'portateis_cozinha_e_preparadores_de_alimentos' THEN 'portable_kitchen_and_food_preparers'
        END,
        'unknown')                                                  AS category,
    CASE WHEN t.product_category_name_english IS NULL
          AND p.product_category_name IS NOT NULL THEN 1 ELSE 0 END AS category_not_translated,
    TRY_CONVERT(int, p.product_weight_g) AS weight_g
FROM stg.products p
LEFT JOIN stg.category_translation t
       ON t.product_category_name = p.product_category_name;
GO

/* Reviews: one order can have several reviews and review_id is not unique.
   We aggregate to one row per order and keep the WORST score (conservative view of quality). */
CREATE OR ALTER VIEW core.order_reviews AS
SELECT
    order_id,
    MIN(TRY_CONVERT(int, review_score))                    AS review_score_min,
    AVG(TRY_CONVERT(decimal(4, 2), review_score))          AS review_score_avg,
    COUNT(*)                                               AS review_count
FROM stg.order_reviews
GROUP BY order_id;
GO
