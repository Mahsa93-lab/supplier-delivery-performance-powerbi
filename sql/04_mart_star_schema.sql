/* 04_mart_star_schema.sql – star schema for Power BI + data-quality checks.

   Two fact tables, because the KPIs live on two different grains:
     mart.fact_orders       one row per ORDER      (99,441)  → customer view: cancellations, delivery on time,
                                                               lead time, complaints. Contains orders WITHOUT items
                                                               (775 canceled/unavailable orders) – an item-level
                                                               table would silently lose them.
     mart.fact_order_items  one row per ORDER ITEM (112,650) → supplier view: revenue, supplier on time, processing time.
   The date dimension is created in Power BI (see powerbi/measures.dax). */
USE olist;
GO

CREATE OR ALTER VIEW mart.dim_seller AS
SELECT seller_id, city, state FROM core.sellers;
GO

CREATE OR ALTER VIEW mart.dim_customer AS
SELECT customer_id, customer_unique_id, city, state FROM core.customers;
GO

CREATE OR ALTER VIEW mart.dim_product AS
SELECT product_id, category, weight_g FROM core.products;
GO

/* ---------- Fact 1: orders (customer view) ---------- */
CREATE OR ALTER VIEW mart.fact_orders AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    CAST(o.purchase_ts AS date)                                           AS purchase_date,
    o.estimated_delivery_date,
    CAST(o.delivered_customer_ts AS date)                                 AS delivered_date,

    CASE WHEN o.order_status = 'delivered' THEN 1 ELSE 0 END              AS is_delivered,
    CASE WHEN o.order_status IN ('canceled', 'unavailable') THEN 1 ELSE 0 END AS is_canceled,

    /* Customer on time: delivered on or before the promised date (only orders with a delivery date) */
    CASE WHEN o.delivered_customer_ts IS NULL OR o.estimated_delivery_date IS NULL THEN NULL
         WHEN CAST(o.delivered_customer_ts AS date) <= o.estimated_delivery_date THEN 1 ELSE 0 END
                                                                          AS delivery_on_time,
    CASE WHEN o.delivered_customer_ts >= o.purchase_ts
         THEN DATEDIFF(day, o.purchase_ts, o.delivered_customer_ts) END   AS lead_time_days,
    CASE WHEN o.delivered_customer_ts IS NOT NULL
         THEN DATEDIFF(day, o.estimated_delivery_date, CAST(o.delivered_customer_ts AS date)) END
                                                                          AS days_late,   -- negative = early

    r.review_score_min,
    CASE WHEN r.review_score_min IS NULL THEN NULL
         WHEN r.review_score_min <= 2 THEN 1 ELSE 0 END                   AS is_complaint,

    COALESCE(i.item_count, 0)                                             AS item_count,
    COALESCE(i.order_value_brl, 0)                                        AS order_value_brl,
    COALESCE(i.freight_brl, 0)                                            AS freight_brl
FROM core.orders o
LEFT JOIN core.order_reviews r ON r.order_id = o.order_id
LEFT JOIN (
    SELECT order_id,
           COUNT(*)         AS item_count,
           SUM(price_brl)   AS order_value_brl,
           SUM(freight_brl) AS freight_brl
    FROM core.order_items
    GROUP BY order_id
) i ON i.order_id = o.order_id;
GO

/* ---------- Fact 2: order items (supplier view) ---------- */
CREATE OR ALTER VIEW mart.fact_order_items AS
SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    o.customer_id,
    o.order_status,
    CAST(o.purchase_ts AS date)                                           AS purchase_date,
    i.price_brl,
    i.freight_brl,

    /* Supplier on time: handed over to the carrier before the agreed shipping limit.
       Note: the carrier date is stored per order, so multi-seller orders share one date. */
    CASE WHEN o.delivered_carrier_ts IS NULL OR i.shipping_limit_ts IS NULL THEN NULL
         WHEN o.delivered_carrier_ts <= i.shipping_limit_ts THEN 1 ELSE 0 END    AS handover_on_time,

    /* Processing time at the supplier (approval → carrier). Illogical sequences (carrier before
       approval, see dq.v_checks) are set to NULL so they do not distort the average. */
    CASE WHEN o.delivered_carrier_ts >= o.approved_ts
         THEN DATEDIFF(day, o.approved_ts, o.delivered_carrier_ts) END            AS seller_processing_days,

    CASE WHEN o.delivered_customer_ts IS NULL OR o.estimated_delivery_date IS NULL THEN NULL
         WHEN CAST(o.delivered_customer_ts AS date) <= o.estimated_delivery_date THEN 1 ELSE 0 END
                                                                                  AS delivery_on_time,
    r.review_score_min,
    CASE WHEN r.review_score_min IS NULL THEN NULL
         WHEN r.review_score_min <= 2 THEN 1 ELSE 0 END                           AS is_complaint
FROM core.order_items i
JOIN core.orders o             ON o.order_id = i.order_id
LEFT JOIN core.order_reviews r ON r.order_id = i.order_id;
GO

/* ---------- Data-quality checks: one row per check → "Data Quality" report page ---------- */
CREATE OR ALTER VIEW dq.v_checks AS
SELECT 1 AS check_id, 'Completeness' AS dimension, 'orders' AS table_name,
       'Delivered order without delivery date' AS check_name,
       SUM(CASE WHEN order_status = 'delivered' AND delivered_customer_ts IS NULL THEN 1 ELSE 0 END) AS failed_rows,
       COUNT(*) AS total_rows
FROM core.orders
UNION ALL
SELECT 2, 'Completeness', 'orders', 'Order without any item',
       SUM(CASE WHEN i.order_id IS NULL THEN 1 ELSE 0 END), COUNT(*)   -- T-SQL: no subquery inside SUM()
FROM core.orders o
LEFT JOIN (SELECT DISTINCT order_id FROM core.order_items) i ON i.order_id = o.order_id
UNION ALL
SELECT 3, 'Completeness', 'orders', 'Order without review',
       SUM(CASE WHEN r.order_id IS NULL THEN 1 ELSE 0 END), COUNT(*)
FROM core.orders o
LEFT JOIN core.order_reviews r ON r.order_id = o.order_id
UNION ALL
SELECT 4, 'Validity', 'orders', 'Purchase timestamp not convertible',
       SUM(CASE WHEN purchase_ts IS NULL THEN 1 ELSE 0 END), COUNT(*)
FROM core.orders
UNION ALL
SELECT 5, 'Consistency', 'orders', 'Handed to carrier before approval',
       SUM(CASE WHEN delivered_carrier_ts < approved_ts THEN 1 ELSE 0 END), COUNT(*)
FROM core.orders
UNION ALL
SELECT 6, 'Consistency', 'orders', 'Handed to carrier before purchase',
       SUM(CASE WHEN delivered_carrier_ts < purchase_ts THEN 1 ELSE 0 END), COUNT(*)
FROM core.orders
UNION ALL
SELECT 7, 'Consistency', 'orders', 'Delivered to customer before carrier pickup',
       SUM(CASE WHEN delivered_customer_ts < delivered_carrier_ts THEN 1 ELSE 0 END), COUNT(*)
FROM core.orders
UNION ALL
SELECT 8, 'Consistency', 'orders', 'Not delivered, but delivery date set',
       SUM(CASE WHEN order_status <> 'delivered' AND delivered_customer_ts IS NOT NULL THEN 1 ELSE 0 END), COUNT(*)
FROM core.orders
UNION ALL
SELECT 9, 'Validity', 'order_items', 'Price missing or <= 0',
       SUM(CASE WHEN price_brl IS NULL OR price_brl <= 0 THEN 1 ELSE 0 END), COUNT(*)
FROM core.order_items
UNION ALL
SELECT 10, 'Uniqueness', 'order_reviews', 'Duplicate review_id rows',
       COUNT(*) - COUNT(DISTINCT review_id), COUNT(*)
FROM stg.order_reviews
UNION ALL
SELECT 11, 'Completeness', 'products', 'Product without category',
       SUM(CASE WHEN category = 'unknown' THEN 1 ELSE 0 END), COUNT(*)
FROM core.products
UNION ALL
SELECT 12, 'Completeness', 'products', 'Category missing in translation file',
       SUM(category_not_translated), COUNT(*)
FROM core.products
UNION ALL
SELECT 13, 'Integrity', 'order_items', 'Item with unknown seller',
       SUM(CASE WHEN s.seller_id IS NULL THEN 1 ELSE 0 END), COUNT(*)
FROM core.order_items i
LEFT JOIN core.sellers s ON s.seller_id = i.seller_id;
GO

-- Quick test – compare with docs/expected-results.md
SELECT COUNT(*) AS fact_orders_rows      FROM mart.fact_orders;        -- expected 99,441
SELECT COUNT(*) AS fact_order_items_rows FROM mart.fact_order_items;   -- expected 112,650
SELECT check_id, dimension, table_name, check_name, failed_rows, total_rows,
       CAST(100.0 * failed_rows / NULLIF(total_rows, 0) AS decimal(6, 2)) AS failed_pct
FROM dq.v_checks
ORDER BY check_id;
