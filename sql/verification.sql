-- 1. Count total rows
SELECT COUNT(*) AS total_rows
FROM csv_data_platform_db.orders_curated;

-- 2. Count rows with null critical columns
SELECT COUNT(*) AS missing_order_id
FROM csv_data_platform_db.orders_curated
WHERE order_id IS NULL;

-- 3. Check negative quantities
SELECT *
FROM csv_data_platform_db.orders_curated
WHERE quantity < 0;

-- 4. Simple business logic: delivered orders > 0
SELECT COUNT(*) AS delivered_orders
FROM csv_data_platform_db.orders_curated
WHERE order_status = 'DELIVERED';
