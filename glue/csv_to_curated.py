import sys
import csv
import boto3
from io import StringIO

def main():
    # Arguments passed from Glue job
    args = dict(arg.split('=') for arg in sys.argv[1:])
    raw_bucket = args.get('--raw_bucket')
    raw_prefix = args.get('--raw_prefix')
    curated_prefix = args.get('--curated_prefix')

    s3 = boto3.client('s3')

    # For demo: process one known file
    raw_key = f"{raw_prefix}orders.csv"

    print(f"Reading file from s3://{raw_bucket}/{raw_key}")

    obj = s3.get_object(Bucket=raw_bucket, Key=raw_key)
    data = obj['Body'].read().decode('utf-8')

    reader = csv.DictReader(StringIO(data))

    required_columns = [
        "order_id",
        "order_date",
        "customer_id",
        "product_name",
        "quantity",
        "unit_price",
        "order_status",
        "created_at"
    ]

    output_rows = []
    error_count = 0

    for row in reader:
        # Basic validation
        for col in required_columns:
            if row.get(col) in (None, ""):
                error_count += 1

        output_rows.append(row)

    print(f"Total rows processed: {len(output_rows)}")
    print(f"Rows with validation issues: {error_count}")

    # Write curated output
    output_buffer = StringIO()
    writer = csv.DictWriter(output_buffer, fieldnames=reader.fieldnames)
    writer.writeheader()
    writer.writerows(output_rows)

    curated_key = f"{curated_prefix}orders_curated.csv"

    s3.put_object(
        Bucket=raw_bucket,
        Key=curated_key,
        Body=output_buffer.getvalue()
    )

    print(f"Curated data written to s3://{raw_bucket}/{curated_key}")

if __name__ == "__main__":
    main()
