# Data Ingestion

## Source
User uploads CSV files to S3 raw zone.

## Raw Zone
- Path: s3://<bucket>/raw/orders/
- Data is immutable
- No transformations applied

## Trigger (Design)
- S3 PUT event triggers AWS Glue job
- Event-based ingestion (near real-time)

## Assumptions
- CSV schema is consistent
- Header row is present
