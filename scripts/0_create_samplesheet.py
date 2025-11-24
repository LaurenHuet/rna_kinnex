#!/usr/bin/env python3
import psycopg2
import os
import pandas as pd
from datetime import date


# run with singularity run $SING/psycopg2:0.1.sif python
# =====================================
# Database connection parameters
# =====================================
db_params = {
    'dbname': 'oceanomics_genomes',
    'user': 'postgres',
    'password': 'oceanomics',
    'host': '131.217.178.144',
    'port': 5432
}

# =====================================
# RNA IDs for the samplesheet (edit as needed)
# =====================================
rna_ids = [
'OG695G_R',
'OG696M_R',
'OG696H_R',
'OG39H_R',
'OG79G_R'
]

# =====================================
# SQL function definition
# - Builds rows for the target RNA IDs
# - Pulls directly from rna_library_kinx
# - Only uses existing columns/tables
# =====================================
create_function_sql = """
CREATE OR REPLACE FUNCTION build_rna_kinx_samplesheet_rows(in_rna_ids text[])
RETURNS TABLE (
  plate            text,
  plate_location   text,
  pool_id          text,
  kinnex_primers   text,
  kinnex_barcodes  text,
  rna_id           text
)
LANGUAGE sql
AS $$
WITH p AS (
  SELECT unnest(in_rna_ids) AS rna_id
)
SELECT
  rlk.plate,
  rlk.plate_location,
  rlk.pool_id,
  rlk.kinnex_primers,
  rlk.kinnex_barcode,
  rlk.rna_id
FROM rna_library_kinx rlk
JOIN p ON rlk.rna_id = p.rna_id
ORDER BY rlk.rna_id;
$$;
"""

# =====================================
# Connect to the database
# =====================================
conn = psycopg2.connect(**db_params)
cur = conn.cursor()

# Create or replace the SQL function
cur.execute(create_function_sql)
conn.commit()

# =====================================
# Call the function with RNA ID list
# =====================================
query = """
SELECT plate, plate_location, pool_id, kinnex_primers, kinnex_barcodes, rna_id
FROM build_rna_kinx_samplesheet_rows(%s);
"""
df = pd.read_sql_query(query, conn, params=(rna_ids,))

# Identify and print rows with missing values (these will be blank in CSV)
missing_rows = df[df.isnull().any(axis=1)]
if not missing_rows.empty:
    print("\nRows with missing values:\n")
    print(missing_rows)

# Close DB connection
cur.close()
conn.close()

# =====================================
# Save CSV to current working directory
# =====================================
output_path = os.path.join(os.getcwd(), "rna_kinx_samplesheet.csv")
df.to_csv(output_path, index=False)

print(f"Samplesheet saved to: {output_path}")
