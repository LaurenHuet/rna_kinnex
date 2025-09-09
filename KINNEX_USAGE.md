# Kinnex Samplesheet Usage Guide

## Overview

This pipeline now supports a complex nested barcode structure for Kinnex sequencing data. The pipeline can handle:

1. **Plate wells** containing multiple Kinnex pools
2. **Kinnex adapter barcodes** (BC01-BC04) that map to bcM000X codes in BAM filenames
3. **IsoSeq primer barcodes** (BC01-BC12) for individual sample identification
4. **Automatic sample renaming** using actual sample names from your lab

## Samplesheet Format

The Kinnex samplesheet requires the following columns:

- `plate_well`: The plate well identifier (e.g., 1_A01, 1_B01, 1_C01)
- `sequencing_sample_id`: The sequencing sample ID from SMRT Link
- `library_type`: Library type (e.g., Kinnex)
- `kinnex_pool`: The Kinnex pool identifier
- `kinnex_adapter_bc`: Kinnex adapter barcode (BC01-BC04)
- `samples_in_pool`: The actual sample name you want in the final output
- `isoseq_primer_bc`: IsoSeq primer barcode (BC01-BC12)

## Example Samplesheet

```csv
plate_well,sequencing_sample_id,library_type,kinnex_pool,kinnex_adapter_bc,samples_in_pool,isoseq_primer_bc
1_A01,PACB_250728_LAAK_P1A1,Kinnex,Pool5_Kinnex_250714_AK,BC01,OG37G_R_KL,BC04
1_A01,PACB_250728_LAAK_P1A1,Kinnex,Pool5_Kinnex_250714_AK,BC01,OG37H_R_KL,BC04
1_B01,PACB_250728_LAAK_P1B1,Kinnex,Pool1_Kinnex_250707_LAAK,BC01,OG14G_R_KL,BC03
```

## Data Directory Structure

Your data should be organized as follows:

```
data/
├── 1_A01/
│   └── hifi/
│       ├── m84154_250728_084101_s1.hifi_reads.bcM0001.bam
│       └── m84154_250728_084101_s1.hifi_reads.bcM0003.bam
├── 1_B01/
│   └── hifi/
│       ├── m84154_250728_104225_s2.hifi_reads.bcM0001.bam
│       └── m84154_250728_104225_s2.hifi_reads.bcM0002.bam
└── 1_C01/
    └── hifi/
        ├── m84154_250728_124434_s3.hifi_reads.bcM0001.bam
        ├── m84154_250728_124434_s3.hifi_reads.bcM0002.bam
        └── m84154_250728_124434_s3.hifi_reads.bcM0004.bam
```

## Barcode Mapping

The pipeline automatically maps:
- `bcM0001` → `BC01`
- `bcM0002` → `BC02`
- `bcM0003` → `BC03`
- `bcM0004` → `BC04`

## Running the Pipeline

### With Kinnex Samplesheet Format

```bash
nextflow run main.nf \
    --kinnex_samplesheet kinnex_samplesheet.csv \
    --data_dir /path/to/your/data \
    --outdir results \
    -profile docker
```

### With Original Simple Format (still supported)

```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --outdir results \
    -profile docker
```

## Output Files

After demultiplexing, your files will be named according to the `samples_in_pool` column:

- `OG37G_R_KL.bam`
- `OG37H_R_KL.bam`
- `OG14G_R_KL.bam`
- etc.

Instead of generic barcode names like:
- `1_A01_bcM0001--IsoSeqX_bc04.bam`

## Parameters

- `--kinnex_samplesheet`: Path to the Kinnex format samplesheet
- `--data_dir`: Path to the root directory containing your plate well directories
- `--input`: Path to simple format samplesheet (alternative to Kinnex format)
- `--outdir`: Output directory for results

## Test Configuration

A test configuration is provided:

```bash
nextflow run main.nf -profile test_kinnex,docker
```

Make sure to update the `data_dir` parameter in `conf/test_kinnex.config` to point to your actual data directory.