# RNA Kinnex Pipeline — User Guide

This pipeline processes PacBio RNA Kinnex data to demultiplex and analyse individual fish samples. It takes concatenated BAM files and separates them into individual fish samples with consistent naming and per-sample QC reports.

## Overview

The pipeline performs the following steps:

1. **SKERA**: Removes adapters from concatenated BAM files
2. **LIMA**: Demultiplexes samples using IsoSeq primers
3. **ISOSEQ_REFINE**: Refines reads to generate full-length non-chimeric (FLNC) reads
4. **RUNQC**: Generates individual QC reports for each fish sample

## Important: Multiple tissues per fish

This pipeline correctly handles cases where multiple tissues from the same fish (e.g., gills and muscle) share the same barcode combination.

When tissues have identical `kinnex_adapter_bc` and `isoseq_primer_bc` values, they are processed together and the final files will have concatenated names like:

`OG107G_R_KL_OG107M_R_KL_1_A01_bcM0001_bc06.flnc.bam`

Where:

- `OG107G_R_KL` = Gills tissue
- `OG107M_R_KL` = Muscle tissue
- Both tissues share the same barcode combination and are in the same demultiplexed file

## Prerequisites

- Nextflow (version 24.10.0 or later)
- Singularity (for containers)
- Access to Pawsey Setonix HPC system
- Your data should be organised in the PacBio Kinnex format

## Step 1: Stage your data

First, copy the raw PacBio data using the provided staging script in the /scripts directory:

```bash
# update these at top of stage_data.sh
# Source directory
RUN=PACB_251117_LAAMD
mkdir -p /scratch/pawsey0964/$USER/RNA/$RUN
SOURCE_DIR="s3:oceanomics/OceanGenomes/pacbio-rna/$RUN/"
DEST_DIR="/scratch/pawsey0964/lhuet/rna_kinnex/$RUN/"


bash scripts/stage_data.sh 
```

This script will organise your data into the expected directory structure:

```
$RUNNAME/
├── 1_A01/
│   ├── m84154_251117_075946_s1.hifi_reads.bcM0001.bam
│   ├── m84154_251117_075946_s1.hifi_reads.bcM0002.bam
│   └── m84154_251117_075946_s1.hifi_reads.bcM0003.bam
├── 1_B01/
│   ├── m84154_251117_083108_s2.hifi_reads.bcM0003.bam
│   └── m84154_251117_083108_s2.hifi_reads.bcM0004.bam
└── ...
```

### Step 2: Create your samplesheet

Open the create_sample_sheet.py and add in the sequencing run id into the script and run using the following

```bash
singularity run $SING/psycopg2:0.1.sif python scripts/create_sample_sheet.py 
```

Example samplesheet (rna_kinx_samplesheet.csv)

```
plate_well,sequencing_sample_id,library_type,kinnex_pool,kinnex_adapter_bc,samples_in_pool,isoseq_primer_bc
1_A01,PACB_251117_LAAMD,PacBio_Kinnex,Pool3_Kinnex_250923_LAAMD,BC03,OG664G_R_KL,BC07
1_A01,PACB_251117_LAAMD,PacBio_Kinnex,Pool1_Kinnex_250923_LAAMD,BC02,OG7M_R_KL,BC03
1_A01,PACB_251117_LAAMD,PacBio_Kinnex,Pool3_Kinnex_250923_LAAMD,BC03,OG9G_R_KL,BC04
1_A01,PACB_251117_LAAMD,PacBio_Kinnex,Pool3_Kinnex_250923_LAAMD,BC03,OG9M_R_KL,BC04
1_A01,PACB_251117_LAAMD,PacBio_Kinnex,Pool2_Kinnex_250923_LAAMD,BC01,OG107M_R_KL,BC06
1_A01,PACB_251117_LAAMD,PacBio_Kinnex,Pool2_Kinnex_250923_LAAMD,BC01,OG107G_R_KL,BC06
1_B01,PACB_251117_LAAMD,PacBio_Kinnex,Pool2_Kinnex_250923_LAAMD,BC03,OG15G_R_KL,BC01
1_B01,PACB_251117_LAAMD,PacBio_Kinnex,Pool2_Kinnex_250923_LAAMD,BC04,OG17G_R_KL,BC08

```

Important notes about the samplesheet

Each row represents one tissue sample (not one fish).
Multiple rows can have the same plate_well if that well contains multiple samples.
Multiple tissues from the same fish can share the same barcode combination:
OG107M_R_KL (muscle) and OG107G_R_KL (gills) both have BC01 + BC06
these will be processed together and combined in the final output
The samples_in_pool column contains your tissue sample names (OG numbers with tissue type)
Tissue naming convention example:
G = Gills (e.g., OG107G_R_KL)
M = Muscle (e.g., OG107M_R_KL)


### Step 3: Run the pipeline

Update the data_dir and outdir in the nextflow_run.sh script and run the script in a tmux session. 

```bash
nextflow run main.nf \
    --kinnex_samplesheet scripts/rna_kinx_samplesheet.csv \
    --data_dir /scratch/pawsey0964/lhuet/rna_kinnex/PACB_251117_LAAMD \
    --outdir /scratch/pawsey0964/lhuet/rna_kinnex/PACB_251117_LAAMD/results \
    -c pawsey.config
```

### Step 3: Compile the results and push to the SQL database

Run the compile_results.sh script from the scripts directory (double check the paths)

```bash
bash compile_results.sh
```
Push results to database, assuming you have your config set up

```bash
singularity run $SING/psycopg2:0.1.sif python push_rna_qc_to_sqldb.py ~/postgresql_details/oceanomics.cfg
```

Back up the data to the PacBio SRA s3 bucket, dry run is automaticlly flagged, as we need to set up the backup directory strture first, so run the dry run and check the strcuture. If happy run the DRY_RUN=0 script.

``bash
bash backup_s3.sh

DRY_RUN=0 bash backup_s3.sh
```
```
### Expected output structure from pipeline
```
results/
├── skera/                          # Adapter-removed BAM files
│   ├── 1_A01_bcM0001.segmented.skera.bam
│   ├── 1_A01_bcM0002.segmented.skera.bam
│   └── ...
├── lima/                           # Demultiplexed BAM files
│   ├── 1_A01_bcM0001.demux.IsoSeqX_bc05_5p--IsoSeqX_3p.bam
│   ├── 1_A01_bcM0002.demux.IsoSeqX_bc02_5p--IsoSeqX_3p.bam
│   └── ...
├── isoseq_refine/                  # Final fish sample BAM files
│   ├── OG664G_R_KL_1_A01_bcM0003_bc07.flnc.bam
│   ├── OG664M_R_KL_1_A01_bcM0003_bc07.flnc.bam
│   ├── OG107G_R_KL_OG107M_R_KL_1_A01_bcM0001_bc06.flnc.bam
│   ├── OG9G_R_KL_1_A01_bcM0003_bc04.flnc.bam
│   └── ...
├── qc_reports/                     # Individual QC reports per sample
│   ├── OG664G_R_KL_1_A01_bcM0003_bc07/
│   │   ├── ccs.report.json
│   │   ├── ccs_accuracy_hist.png
│   │   └── ...
│   ├── OG107G_R_KL_OG107M_R_KL_1_A01_bcM0001_bc06/
│   │   ├── ccs.report.json
│   │   ├── ccs_accuracy_hist.png
│   │   └── ...
│   └── ...
└── pipeline_info/                  # Nextflow execution reports
    ├── execution_report.html
    ├── execution_timeline.html
    └── execution_trace.txt
```

### Expected output structure from backup

```
├── OG105
│   └── rna
│       ├── OG105G_R_KL_1_D01_bcM0002_bc12.flnc.bam
│       ├── OG105G_R_KL_1_D01_bcM0002_bc12.flnc.consensusreadset.xml
│       └── OG105G_R_KL_1_D01_bcM0002_bc12_qc_reports
│           ├── ccs.report.json
│           ├── ccs_accuracy_hist.png
│           ├── ccs_accuracy_hist_thumb.png
│           ├── ccs_all_readlength_hist_plot.png
│           ├── ccs_all_readlength_hist_plot_thumb.png
│           ├── ccs_hifi_read_length_yield_plot.png
│           ├── ccs_hifi_read_length_yield_plot_thumb.png
│           ├── readlength_qv_hist2d.hexbin.png
│           └── readlength_qv_hist2d.hexbin_thumb.png
├── OG107
│   └── rna
│       ├── OG107G_R_KL_OG107M_R_KL_1_A01_bcM0001_bc06.flnc.bam
│       ├── OG107G_R_KL_OG107M_R_KL_1_A01_bcM0001_bc06.flnc.consensusreadset.xml
│       └── OG107G_R_KL_OG107M_R_KL_1_A01_bcM0001_bc06_qc_reports
│           ├── ccs.report.json
│           ├── ccs_accuracy_hist.png
│           ├── ccs_accuracy_hist_thumb.png
│           ├── ccs_all_readlength_hist_plot.png
│           ├── ccs_all_readlength_hist_plot_thumb.png
│           ├── ccs_hifi_read_length_yield_plot.png
│           ├── ccs_hifi_read_length_yield_plot_thumb.png
│           ├── readlength_qv_hist2d.hexbin.png
│           └── readlength_qv_hist2d.hexbin_thumb.png

```
