#!/bin/bash --login
#---------------
#Requested resources:
#SBATCH --account=pawsey0964
#SBATCH --job-name=lima
#SBATCH --partition=work
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --time=08:00:00
#SBATCH --mem=60G
#SBATCH --export=ALL
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err

input_bam=$1
output_prefix=$2

singularity run $SING/lima:2.13.0.sif lima --isoseq --peek-guess $input_bam IsoSeq_v2_primers_12.fasta ${output_prefix}.segmented.lima.bam --log-file lima.log
