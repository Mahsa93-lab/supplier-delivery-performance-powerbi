/* 02_profiling.sql – first look at the raw data (run after the Python loader).
   Copy interesting results into docs/data-profiling.md – this becomes part of the README. */
USE olist;
GO

-- 1) Row counts per staging table
SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM stg.orders UNION ALL
SELECT 'order_items',          COUNT(*) FROM stg.order_items UNION ALL
SELECT 'customers',            COUNT(*) FROM stg.customers UNION ALL
SELECT 'sellers',              COUNT(*) FROM stg.sellers UNION ALL
SELECT 'products',             COUNT(*) FROM stg.products UNION ALL
SELECT 'order_reviews',        COUNT(*) FROM stg.order_reviews UNION ALL
SELECT 'order_payments',       COUNT(*) FROM stg.order_payments UNION ALL
SELECT 'category_translation', COUNT(*) FROM stg.category_translation;

-- 2) Order status distribution
SELECT order_status, COUNT(*) AS orders
FROM stg.orders
GROUP BY order_status
ORDER BY orders DESC;

-- 3) Missing timestamps per status (completeness)
SELECT order_status,
       SUM(CASE WHEN order_approved_at             IS NULL THEN 1 ELSE 0 END) AS missing_approved,
       SUM(CASE WHEN order_delivered_carrier_date  IS NULL THEN 1 ELSE 0 END) AS missing_carrier,
       SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS missing_customer
FROM stg.orders
GROUP BY order_status;

-- 4) Values that cannot be converted to a date (validity)
SELECT COUNT(*) AS invalid_purchase_ts
FROM stg.orders
WHERE order_purchase_timestamp IS NOT NULL
  AND TRY_CONVERT(datetime2(0), order_purchase_timestamp, 120) IS NULL;

-- 5) Duplicates (uniqueness)
SELECT 'orders.order_id' AS key_column, COUNT(*) - COUNT(DISTINCT order_id) AS duplicates FROM stg.orders UNION ALL
SELECT 'order_reviews.review_id',        COUNT(*) - COUNT(DISTINCT review_id) FROM stg.order_reviews UNION ALL
SELECT 'sellers.seller_id',              COUNT(*) - COUNT(DISTINCT seller_id) FROM stg.sellers;

-- 6) Illogical sequences (consistency): delivered before purchase / handed to carrier before approval
SELECT
    SUM(CASE WHEN TRY_CONVERT(datetime2(0), order_delivered_customer_date, 120)
                < TRY_CONVERT(datetime2(0), order_purchase_timestamp, 120) THEN 1 ELSE 0 END) AS delivered_before_purchase,
    SUM(CASE WHEN TRY_CONVERT(datetime2(0), order_delivered_carrier_date, 120)
                < TRY_CONVERT(datetime2(0), order_approved_at, 120) THEN 1 ELSE 0 END)        AS carrier_before_approval
FROM stg.orders;

-- 7) Orphans (referential integrity): items whose seller or product does not exist
SELECT
    SUM(CASE WHEN s.seller_id  IS NULL THEN 1 ELSE 0 END) AS items_without_seller,
    SUM(CASE WHEN p.product_id IS NULL THEN 1 ELSE 0 END) AS items_without_product
FROM stg.order_items i
LEFT JOIN stg.sellers  s ON s.seller_id  = i.seller_id
LEFT JOIN stg.products p ON p.product_id = i.product_id;
