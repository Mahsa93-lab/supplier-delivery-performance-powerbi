/* 05_validate.sql – automatic test: compares the database with docs/expected-results.md.
   Every row must show PASS. Run after 04_mart_star_schema.sql. */
USE olist;
GO

WITH actual AS (
    SELECT 'stg.orders rows'            AS test_name, CAST(COUNT(*) AS decimal(18, 2)) AS actual_value FROM stg.orders
    UNION ALL SELECT 'stg.order_items rows',      COUNT(*) FROM stg.order_items
    UNION ALL SELECT 'stg.customers rows',        COUNT(*) FROM stg.customers
    UNION ALL SELECT 'stg.sellers rows',          COUNT(*) FROM stg.sellers
    UNION ALL SELECT 'stg.products rows',         COUNT(*) FROM stg.products
    UNION ALL SELECT 'stg.order_reviews rows',    COUNT(*) FROM stg.order_reviews
    UNION ALL SELECT 'mart.fact_orders rows',     COUNT(*) FROM mart.fact_orders
    UNION ALL SELECT 'mart.fact_order_items rows', COUNT(*) FROM mart.fact_order_items
    UNION ALL SELECT 'revenue BRL (all)',         SUM(price_brl) FROM mart.fact_order_items
    UNION ALL SELECT 'canceled orders',           SUM(is_canceled) FROM mart.fact_orders
    UNION ALL SELECT 'late orders',               SUM(CASE WHEN delivery_on_time = 0 THEN 1 ELSE 0 END) FROM mart.fact_orders
    UNION ALL SELECT 'late handovers',            SUM(CASE WHEN handover_on_time = 0 THEN 1 ELSE 0 END) FROM mart.fact_order_items
    UNION ALL SELECT 'customer OTD % (all)',
              CAST(ROUND(100.0 * SUM(CASE WHEN delivery_on_time = 1 THEN 1 ELSE 0 END) / COUNT(delivery_on_time), 2) AS decimal(18, 2))
              FROM mart.fact_orders
    UNION ALL SELECT 'supplier OTD % (all)',
              CAST(ROUND(100.0 * SUM(CASE WHEN handover_on_time = 1 THEN 1 ELSE 0 END) / COUNT(handover_on_time), 2) AS decimal(18, 2))
              FROM mart.fact_order_items
    UNION ALL SELECT 'DQ failed rows (sum)',      SUM(failed_rows) FROM dq.v_checks
),
expected AS (
    SELECT * FROM (VALUES
        ('stg.orders rows',             99441.00),
        ('stg.order_items rows',       112650.00),
        ('stg.customers rows',          99441.00),
        ('stg.sellers rows',             3095.00),
        ('stg.products rows',           32951.00),
        ('stg.order_reviews rows',      99224.00),
        ('mart.fact_orders rows',       99441.00),
        ('mart.fact_order_items rows', 112650.00),
        ('revenue BRL (all)',        13591643.70),
        ('canceled orders',              1234.00),
        ('late orders',                  6535.00),
        ('late handovers',              10423.00),
        ('customer OTD % (all)',           93.23),
        ('supplier OTD % (all)',           90.65),
        ('DQ failed rows (sum)',         4542.00)
    ) AS v (test_name, expected_value)
)
SELECT e.test_name,
       e.expected_value,
       a.actual_value,
       CASE WHEN a.actual_value = e.expected_value THEN 'PASS' ELSE 'FAIL' END AS result
FROM expected e
LEFT JOIN actual a ON a.test_name = e.test_name
ORDER BY CASE WHEN a.actual_value = e.expected_value THEN 1 ELSE 0 END, e.test_name;
