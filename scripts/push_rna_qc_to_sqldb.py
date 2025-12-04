#!/usr/bin/env python3
# singularity run $SING/psycopg2:0.1.sif python push_rna_qc_to_sqldb.py ~/postgresql_details/oceanomics.cfg

import psycopg2
import pandas as pd
import numpy as np
import configparser
import sys
from pathlib import Path

def load_db_config(config_file):
    if not Path(config_file).exists():
        raise FileNotFoundError(f"❌ Config file '{config_file}' does not exist.")
    config = configparser.ConfigParser()
    config.read(config_file)
    if not config.has_section('postgres'):
        raise ValueError("❌ Missing [postgres] section in config file.")
    required_keys = ['dbname', 'user', 'password', 'host', 'port']
    for key in required_keys:
        if not config.has_option('postgres', key):
            raise ValueError(f"❌ Missing '{key}' in [postgres] section of config file.")
    return {
        'dbname': config.get('postgres', 'dbname'),
        'user': config.get('postgres', 'user'),
        'password': config.get('postgres', 'password'),
        'host': config.get('postgres', 'host'),
        'port': config.getint('postgres', 'port')
    }

def parse_int(val):
    s = str(val).strip().replace(",", "")
    if s == "" or s.lower() in ("nan", "na"):
        return None
    try:
        return int(s)
    except ValueError:
        return None

def parse_text(val):
    if val is None:
        return None
    s = str(val).strip()
    if s == "" or s.lower() in ("nan", "na"):
        return None
    return s

config_file = sys.argv[1]
rna_path = "rna_read_counts.tsv"

print(f"Importing data from {rna_path}")
rna = pd.read_csv(rna_path, sep="\t")

required_cols = ["rna_tube_id", "rna_tube_id_2", "read_count", "run_id"]
missing = [c for c in required_cols if c not in rna.columns]
if missing:
    raise ValueError(f"❌ Missing required columns: {missing}")

conn = None
cursor = None

try:
    db_params = load_db_config(config_file)
    conn = psycopg2.connect(**db_params)
    cursor = conn.cursor()

    update_query = """
    UPDATE rna_qc_kinnex
    SET rna_tube_id_2 = %(rna_tube_id_2)s,
        read_count    = %(read_count)s,
        run_id        = %(run_id)s
    WHERE rna_tube_id = %(rna_tube_id)s;
    """

    insert_query = """
    INSERT INTO rna_qc_kinnex (rna_tube_id, rna_tube_id_2, read_count, run_id)
    VALUES (%(rna_tube_id)s, %(rna_tube_id_2)s, %(read_count)s, %(run_id)s);
    """

    row_count = 0
    for _, row in rna.iterrows():
        params = {
            "rna_tube_id":   parse_text(row.get("rna_tube_id")),
            "rna_tube_id_2": parse_text(row.get("rna_tube_id_2")),
            "read_count":    parse_int(row.get("read_count")),
            "run_id":        parse_text(row.get("run_id")),
        }
        if not params["rna_tube_id"]:
            continue

        cursor.execute(update_query, params)
        if cursor.rowcount == 0:
            cursor.execute(insert_query, params)

        row_count += 1

    conn.commit()
    print(f"✅ Successfully processed {row_count} rows!")

except Exception as e:
    if conn:
        conn.rollback()
    print(f"❌ Error: {e}")

finally:
    if cursor:
        cursor.close()
    if conn:
        conn.close()
