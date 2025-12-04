#!/bin/bash

# Example command to run the RNA Kinnex pipeline on Pawsey with multiple samples
# 1. First, create your samplesheet.csv with your actual BAM file paths
# 2. Then run this script

nextflow run main.nf \
    --kinnex_samplesheet scripts/rna_kinx_samplesheet.csv \
    --data_dir /scratch/pawsey0964/lhuet/rna_kinnex/PACB_251117_LAAMD \
    --outdir /scratch/pawsey0964/lhuet/rna_kinnex/PACB_251117_LAAMD/results \
    -c pawsey.config