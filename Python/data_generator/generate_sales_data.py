import pandas as pd
import random
import json
import os
from datetime import datetime, timedelta

# ----------------------------
# Read master data
# ----------------------------

vehicle_df = pd.read_csv("vehicle_master.csv")
dealer_df = pd.read_csv("dealer_master.csv")
customer_df = pd.read_csv("customer_master.csv")

# ----------------------------
# Create output folder
# ----------------------------

os.makedirs("sales_data", exist_ok=True)

# ----------------------------
# Generate valid records
# ----------------------------

sales_records = []

start_date = datetime(2025, 1, 1)
end_date = datetime(2025, 12, 31)

for i in range(1, 5001):

    vehicle = vehicle_df.sample(1).iloc[0]
    dealer = dealer_df.sample(1).iloc[0]
    customer = customer_df.sample(1).iloc[0]

    random_days = random.randint(
        0,
        (end_date - start_date).days
    )

    sale_date = (
        start_date +
        timedelta(days=random_days)
    ).strftime("%Y-%m-%d")

    record = {
        "sale_id": f"SAL{i:08d}",
        "sale_date": sale_date,
        "customer_id": customer["customer_id"],
        "dealer_id": dealer["dealer_id"],
        "vehicle_id": vehicle["vehicle_id"],
        "quantity": random.randint(1, 5),
        "unit_price": round(
            vehicle["base_price_usd"] *
            random.uniform(0.95, 1.05),
            2
        ),
        "sales_channel": random.choice(
            [
                "Dealership",
                "Online",
                "Corporate"
            ]
        )
    }

    sales_records.append(record)

# ----------------------------
# Generate bad records
# ----------------------------

for i in range(100):

    bad_record = {
        "sale_id": None,
        "sale_date": "2035-01-01",
        "customer_id": "BAD_CUSTOMER",
        "dealer_id": "BAD999",
        "vehicle_id": "INVALID_VEHICLE",
        "quantity": -1,
        "unit_price": -5000,
        "sales_channel": "UNKNOWN"
    }

    sales_records.append(bad_record)

# ----------------------------
# Shuffle data
# ----------------------------

random.shuffle(sales_records)

# ----------------------------
# Split into 100 files
# ----------------------------

records_per_file = len(sales_records) // 100

for file_num in range(100):

    start_idx = file_num * records_per_file
    end_idx = start_idx + records_per_file

    chunk = sales_records[start_idx:end_idx]

    file_name = (
        f"sales_data/"
        f"sales_{file_num+1:03d}.json"
    )

    with open(file_name, "w") as f:

        json.dump(
            chunk,
            f,
            indent=4
        )

print("Done!")
print(f"Total records: {len(sales_records)}")
print("Files created: 100")