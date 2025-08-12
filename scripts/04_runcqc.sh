#!/bin/bash --login
#---------------
#Requested resources:
#SBATCH --account=pawsey0812
#SBATCH --job-name=runqc_kinnex
#SBATCH --partition=work
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=6
#SBATCH --time=01:00:00
#SBATCH --mem=20G
#SBATCH --export=ALL
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err


bash /software/projects/pawsey0964/smrtlink/smrtlink/smrtcmds/bin/runqc-reports flnc.consensusreadset.xml
