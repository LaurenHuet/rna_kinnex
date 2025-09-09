#!/usr/bin/env python3
"""
Convert lab Kinnex RNA CSV to pipeline-compatible samplesheet.

Usage:
  python convert_kinnex_samplesheet_v2.py lab_kinnex_rna.csv out_samplesheet.csv

This script reads the lab CSV (as exported from the Kinnex template) and outputs:
  plate_well, sequencing_sample_id, library_type, kinnex_pool,
  kinnex_adapter_bc, samples_in_pool, isoseq_primer_bc

It handles:
  - Excel non‑breaking spaces in headers
  - Forward-filling group fields (plate, sequencing ID, library type, pool, adapter)
  - Converting "Plate 1- A01" → "1_A01"
"""

import sys
import re
import pandas as pd
import numpy as np
from pathlib import Path

def normalise_headers(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df.columns = [c.replace("\xa0", " ").strip() for c in df.columns]
    return df

def tidy_plate_well(val: str) -> str:
    if pd.isna(val):
        return np.nan
    s = str(val).strip()
    m = re.search(r"[Pp]late\s*(\d+)\s*[-–]\s*([A-H]\d{2})", s)
    if m:
        return f"{m.group(1)}_{m.group(2)}"
    # if already in tidy format, keep it
    if re.match(r"^\d+_[A-H]\d{2}$", s):
        return s
    return s

def convert(lab_csv: str, out_csv: str) -> pd.DataFrame:
    df = pd.read_csv(lab_csv, dtype=str)
    df = normalise_headers(df)

    col_plate = "Sample Plate Well"
    col_seqid = "Sequencing Sample ID (will put as sample name in smrtlink)"
    col_lib   = "Library type/sequencing purpose"
    col_pool  = 'Kinnex "pool"'
    col_adapt = "Kinnex adapter bc (BC01-BC04)"
    col_samp  = "Samples In pool"
    col_iso   = "Isoseq primer barcodes (Bc1-12)"

    for c in [col_plate, col_seqid, col_lib, col_pool, col_adapt]:
        df[c] = df[c].ffill()

    df = df[~df[col_samp].isna()].copy()

    out = pd.DataFrame({
        "plate_well": df[col_plate].map(tidy_plate_well),
        "sequencing_sample_id": df[col_seqid].str.strip(),
        "library_type": df[col_lib].str.strip(),
        "kinnex_pool": df[col_pool].str.strip(),
        "kinnex_adapter_bc": df[col_adapt].str.strip(),
        "samples_in_pool": df[col_samp].str.strip(),
        "isoseq_primer_bc": df[col_iso].str.strip(),
    })

    out.to_csv(out_csv, index=False)
    return out

def main(argv=None):
    args = sys.argv if argv is None else argv
    if len(args) != 3:
        print("Usage: python convert_kinnex_samplesheet_v2.py <lab.csv> <out.csv>")
        sys.exit(1)
    lab_csv, out_csv = args[1], args[2]
    out = convert(lab_csv, out_csv)
    print(f"Wrote {len(out)} rows to {out_csv}")

if __name__ == "__main__":
    main()
