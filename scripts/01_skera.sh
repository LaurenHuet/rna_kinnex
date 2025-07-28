#!/bin/bash --login
#---------------
#Requested resources:
#SBATCH --account=pawsey0964
#SBATCH --job-name=skera
#SBATCH --partition=work
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=12
#SBATCH --time=6:00:00
#SBATCH --mem=40G
#SBATCH --export=ALL
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err

input_hifi=$1

singularity run $SING2/pbskera:1.4.0.sif skera split $input_hifi mas8_primers.fasta segmented.skera.bam
