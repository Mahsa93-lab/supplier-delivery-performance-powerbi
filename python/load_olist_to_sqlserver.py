"""Load the Olist CSV files into SQL Server (schema `stg`).

Usage (Windows, inside the project folder):
    python -m venv .venv
    .venv\\Scripts\\activate
    pip install -r requirements.txt
    python python\\load_olist_to_sqlserver.py --csv-dir C:\\data\\olist

Prerequisites:
    * SQL Server 2022 Express + ODBC Driver 18 for SQL Server
    * Database and schemas created with sql/01_create_database.sql
    * Olist CSVs downloaded from Kaggle ("Brazilian E-Commerce Public Dataset by Olist")

All columns are loaded as text (NVARCHAR). Type conversion happens later in
the `core` views (sql/03_core_views.sql) – this keeps the raw layer untouched and
makes data-quality problems visible instead of silently dropping them.
"""
from __future__ import annotations

import argparse
import math
import time
from pathlib import Path

import pandas as pd
from sqlalchemy import URL, create_engine, text
from sqlalchemy.dialects.mssql import NVARCHAR

# file name -> staging table name
FILES = {
    "olist_orders_dataset.csv": "orders",
    "olist_order_items_dataset.csv": "order_items",
    "olist_customers_dataset.csv": "customers",
    "olist_sellers_dataset.csv": "sellers",
    "olist_products_dataset.csv": "products",
    "olist_order_reviews_dataset.csv": "order_reviews",
    "olist_order_payments_dataset.csv": "order_payments",
    "product_category_name_translation.csv": "category_translation",
}
OPTIONAL_FILES = {"olist_geolocation_dataset.csv": "geolocation"}  # ~1 million rows


def build_engine(server: str, database: str):
    """Windows authentication (your Windows login) via ODBC Driver 18 for SQL Server."""
    odbc = (
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={server};DATABASE={database};"
        "Trusted_Connection=yes;TrustServerCertificate=yes"
    )
    return create_engine(URL.create("mssql+pyodbc", query={"odbc_connect": odbc}), fast_executemany=True)


def text_types(df: pd.DataFrame) -> dict:
    """NVARCHAR(n) per column (n = 1.5 × longest value, 50…4000).

    NVARCHAR keeps accents (São Paulo). A fixed length instead of NVARCHAR(MAX) keeps
    pyodbc's fast_executemany fast – with MAX columns it becomes very slow.
    """
    types = {}
    for col in df.columns:
        longest = int(df[col].dropna().str.len().max() or 0)
        types[col] = NVARCHAR(min(4000, max(50, math.ceil(longest * 1.5))))
    return types


def load_file(engine, csv_path: Path, table: str) -> int:
    df = pd.read_csv(csv_path, dtype=str, keep_default_na=False, na_values=[""], encoding="utf-8-sig")
    df.columns = [c.strip().lower() for c in df.columns]
    df.to_sql(table, engine, schema="stg", if_exists="replace", index=False, dtype=text_types(df), chunksize=5_000)
    return len(df)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--csv-dir", required=True, type=Path)
    parser.add_argument("--server", default=r"localhost\SQLEXPRESS")
    parser.add_argument("--database", default="olist")
    parser.add_argument("--with-geolocation", action="store_true")
    args = parser.parse_args()

    files = dict(FILES)
    if args.with_geolocation:
        files.update(OPTIONAL_FILES)

    engine = build_engine(args.server, args.database)
    with engine.connect() as conn:  # fail fast if the connection is wrong
        conn.execute(text("SELECT 1"))

    for file_name, table in files.items():
        path = args.csv_dir / file_name
        if not path.exists():
            print(f"!! missing: {path}")
            continue
        start = time.perf_counter()
        rows = load_file(engine, path, table)
        print(f"stg.{table:<22} {rows:>9,} rows  ({time.perf_counter() - start:.1f}s)")


if __name__ == "__main__":
    main()
