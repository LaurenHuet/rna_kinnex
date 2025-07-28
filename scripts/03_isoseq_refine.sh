#!/bin/bash --login
#---------------
#Requested resources:
#SBATCH --account=pawsey0812
#SBATCH --job-name=isoseq_refine
#SBATCH --partition=work
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=24
#SBATCH --time=08:00:00
#SBATCH --mem=80G
#SBATCH --export=ALL
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err

input_files=$1   ##all.fofn
output_prefix=$2

singularity run $SING2/isoseq:4.3.0.sif isoseq refine $input_files IsoSeq_v2_primers_12.fasta ${output_prefix}.flnc.bam --require-polya
