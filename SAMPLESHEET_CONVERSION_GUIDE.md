# Samplesheet Conversion Guide

## Step-by-Step Process

### Step 1: Understanding Your Lab's Data

Your lab provides data in this format:
```
Sample Plate Well  Sequencing Sample ID  Library type  Kinnex "pool"  Kinnex adapter bc  Samples In pool  Isoseq primer barcodes
Plate 1- A01       PACB_250728_LAAK_P1A1  Kinnex       Pool5_Kinnex_250714_AK  BC01  OG37G_R_KL  BC04
```

### Step 2: What the Parser Needs

The pipeline expects this CSV format:
```csv
plate_well,sequencing_sample_id,library_type,kinnex_pool,kinnex_adapter_bc,samples_in_pool,isoseq_primer_bc
1_A01,PACB_250728_LAAK_P1A1,Kinnex,Pool5_Kinnex_250714_AK,BC01,OG37G_R_KL,BC04
```

### Step 3: Key Transformations

1. **Plate Well Format**: 
   - Lab: `Plate 1- A01` 
   - Pipeline: `1_A01`

2. **Column Mapping**:
   - `Sample Plate Well` → `plate_well`
   - `Sequencing Sample ID` → `sequencing_sample_id`
   - `Library type` → `library_type`
   - `Kinnex "pool"` → `kinnex_pool`
   - `Kinnex adapter bc` → `kinnex_adapter_bc`
   - `Samples In pool` → `samples_in_pool`
   - `Isoseq primer barcodes` → `isoseq_primer_bc`

### Step 4: How the Parser Works Internally

When you run the pipeline, the parser:

1. **Reads your CSV** and creates a nested mapping:
   ```
   1_A01 (plate well)
     └── BC01 (Kinnex adapter)
         ├── BC04 → OG37G_R_KL
         ├── BC04 → OG37H_R_KL
         ├── BC06 → OG46G_R_KL
         └── BC09 → OG85G_R_KL
     └── BC03 (Kinnex adapter)
         ├── BC10 → OG88G_R_KL2
         └── BC11 → OG88M_R_KL2
   ```

2. **Maps BAM files** to samples:
   - Finds: `1_A01/hifi/m84154_250728_084101_s1.hifi_reads.bcM0001.bam`
   - Maps: `bcM0001` → `BC01` → finds all samples in BC01 pool
   - During demultiplexing: `BC04` → `OG37G_R_KL.bam`

3. **Renames output files** with actual sample names instead of barcodes

### Step 5: Manual Conversion Process

If you have your lab's data in a spreadsheet:

1. **Open your lab's data** in Excel/Google Sheets
2. **Create new columns** with the pipeline headers:
   - `plate_well`
   - `sequencing_sample_id`
   - `library_type`
   - `kinnex_pool`
   - `kinnex_adapter_bc`
   - `samples_in_pool`
   - `isoseq_primer_bc`

3. **Transform the data**:
   - Convert `Plate 1- A01` to `1_A01`
   - Copy other columns as-is
   - Make sure each sample gets its own row

4. **Save as CSV**

### Step 6: Using the Conversion Script

I've created a Python script to help you:

```bash
# Run the conversion script
cd rna_kinnex
python convert_lab_sheet.py
```

This creates `converted_samplesheet.csv` with the correct format.

### Step 7: Verify Your Data Structure

Make sure your data directory matches this structure:
```
your_data/
├── 1_A01/
│   └── hifi/
│       ├── m84154_250728_084101_s1.hifi_reads.bcM0001.bam  # Maps to BC01
│       └── m84154_250728_084101_s1.hifi_reads.bcM0003.bam  # Maps to BC03
├── 1_B01/
│   └── hifi/
│       └── m84154_250728_104225_s2.hifi_reads.bcM0001.bam  # Maps to BC01
└── 1_C01/
    └── hifi/
        ├── m84154_250728_124434_s3.hifi_reads.bcM0001.bam  # Maps to BC01
        ├── m84154_250728_124434_s3.hifi_reads.bcM0002.bam  # Maps to BC02
        └── m84154_250728_124434_s3.hifi_reads.bcM0004.bam  # Maps to BC04
```

### Step 8: Run the Pipeline

```bash
nextflow run main.nf \
    --kinnex_samplesheet converted_samplesheet.csv \
    --data_dir /path/to/your/data \
    --outdir results \
    -profile docker
```

## What Happens During Processing

1. **SKERA**: Removes adapters from each BAM file
2. **LIMA_KINNEX**: 
   - Demultiplexes using IsoSeq primers (BC01-BC12)
   - Uses your sample mapping to rename files
   - Output: `OG37G_R_KL.bam` instead of `1_A01_bcM0001--IsoSeqX_bc04.bam`
3. **ISOSEQ_REFINE**: Refines reads with proper sample names
4. **RUNQC**: Generates QC reports

## Troubleshooting

### Common Issues:

1. **"Directory not found"**: Check that your `--data_dir` path is correct
2. **"No BAM files found"**: Verify your directory structure matches the expected format
3. **"Sample mapping not found"**: Check that your Kinnex adapter codes (BC01-BC04) match the bcM codes in your BAM filenames

### Barcode Mapping Reference:
- `bcM0001` → `BC01`
- `bcM0002` → `BC02`
- `bcM0003` → `BC03`
- `bcM0004` → `BC04`

If your BAM files use different bcM codes, let me know and I can update the mapping!