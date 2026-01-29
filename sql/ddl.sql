CREATE EXTERNAL TABLE IF NOT EXISTS csv_data_platform_db.orders_curated (
    order_id BIGINT,
    order_date STRING,
    customer_id STRING,
    product_name STRING,
    quantity INT,
    unit_price DOUBLE,
    discount DOUBLE,
    order_status STRING,
    created_at STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
WITH SERDEPROPERTIES (
    'separatorChar' = ',',
    'quoteChar'     = '"'
)
LOCATION 's3://<bucket>/curated/orders/'
TBLPROPERTIES ('has_encrypted_data'='false');
