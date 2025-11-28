#!/usr/bin/env python3
import psycopg2
import os
import pandas as pd

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
# Input run_id instead of RNA IDs
# =====================================
run_id = "PACB_251117_LAAMD"   # <-- change as needed

# =====================================
# SQL function definition
# =====================================
create_function_sql = """
CREATE OR REPLACE FUNCTION build_rna_kinx_samplesheet_from_run(in_run_id text)
RETURNS TABLE (
  plate_well          text,
  sequencing_sample_id text,
  library_type        text,
  kinnex_pool         text,
  kinnex_adapter_bc   text,
  samples_in_pool     text,
  isoseq_primer_bc    text
)
LANGUAGE sql
AS $$
WITH tubes AS (
    SELECT DISTINCT rna_library_tube_id
    FROM sequencing
    WHERE run_id = in_run_id
),
matched AS (
    SELECT
        -- 1_A01, 1_B01, etc.
        concat(rlk.plate, '_', rlk.plate_location, '01') AS plate_well,
        s.run_id AS sequencing_sample_id,     
        replace(rlk.library_method, ' ', '_') AS library_type,
        rlk.pool_id      AS kinnex_pool,
        rlk.kinnex_barcode AS kinnex_adapter_bc,
        s.rna_library_tube_id   AS samples_in_pool,
        rlk.kinnex_primers AS isoseq_primer_bc

    FROM rna_library_kinx rlk
    JOIN tubes t
      ON t.rna_library_tube_id = rlk.rna_library_tube_id
    JOIN sequencing s
      ON s.rna_library_tube_id = rlk.rna_library_tube_id
     AND s.run_id = in_run_id
)
SELECT *
FROM matched
ORDER BY plate_well;
$$;
"""

# =====================================
# Connect to DB and create function
# =====================================
conn = psycopg2.connect(**db_params)
cur = conn.cursor()

# Drop old version so we can change the RETURN TABLE signature
cur.execute("DROP FUNCTION IF EXISTS build_rna_kinx_samplesheet_from_run(text);")
conn.commit()

cur.execute(create_function_sql)
conn.commit()

# =====================================
# Query the function
# =====================================
query = """
SELECT *
FROM build_rna_kinx_samplesheet_from_run(%s);
"""

df = pd.read_sql_query(query, conn, params=(run_id,))

# Print missing rows
missing_rows = df[df.isnull().any(axis=1)]
if not missing_rows.empty:
    print("\nRows with missing values:\n")
    print(missing_rows)

cur.close()
conn.close()

# =====================================
# Save CSV
# =====================================
output_path = os.path.join(os.getcwd(), "rna_kinx_samplesheet.csv")
df.to_csv(output_path, index=False)

print(f"Samplesheet saved to: {output_path}")
