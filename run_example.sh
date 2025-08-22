#!/bin/bash

# Example command to run the RNA Kinnex pipeline on Pawsey with multiple samples
# 1. First, create your samplesheet.csv with your actual BAM file paths
# 2. Then run this script


# Example with sample sheet
nextflow run . \
    --input samplesheet.csv \
    --outdir ./results \
    -profile singularity \
    -resume \
    -c pawsey.config

# Alternative: if you want to specify custom primer files
# nextflow run . \
#     --input samplesheet.csv \
#     --mas8_primers /path/to/custom/mas8_primers.fasta \
#     --isoseq_primers /path/to/custom/isoseq_primers.fasta \
#     --outdir ./results \
#     -profile pawsey \
#     -resume