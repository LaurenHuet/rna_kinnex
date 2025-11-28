#!/bin/bash

# Source directory
RUN=PACB_251117_LAAMD
#mkdir -p /scratch/pawsey0964/lhuet/$RUN
SOURCE_DIR="s3:oceanomics/OceanGenomes/pacbio-sra/$RUN/"
DEST_DIR="/scratch/pawsey0964/lhuet/rna_kinnex/$RUN/"


# Filtered files
FILES=$(rclone ls "$SOURCE_DIR" --include "*.bam" | grep "hifi_reads")


# Loop through each file
while IFS= read -r line; do
    # Extract the plate number from path
    COMBINATION=$(echo "$line" | awk -F'/' '{print $2}')
    #echo $COMBINATION
    # Extract file Path 
    FILE_PATH=$(echo "$line" | awk '{print $NF}' | rev | cut -d'/' -f2- | rev)
    #echo $FILE_PATH
    # Extract the filename
    FILENAME=$(echo "$line" | awk -F'/' '{print $NF}')
    #echo $FILENAME
    # Create directory structure in the destination path
    DEST_PATH="$DEST_DIR$COMBINATION/"


#SOME ECHOS TO TEST YOUR PATHS 
    #echo "$SOURCE_DIR$FILE_PATH/$FILENAME" "$DEST_PATH$FILENAME"
    #echo $DEST_PATH
    mkdir -p "$DEST_PATH"
        # Submit SLURM job to copy file
    sbatch <<EOT
#!/bin/bash
#SBATCH --job-name=copy_${COMBINATION}
#SBATCH --output=copy_${COMBINATION}_%j.out
#SBATCH --error=copy_${COMBINATION}_%j.err
#SBATCH --ntasks=1
#SBATCH --time=12:00:00
#SBATCH --partition=work     
#SBATCH --account=pawsey0812
#SBATCH --ntasks=1
#SBATCH --export=NONE
#SBATCH --mail-type=BEGIN,END
#SBATCH --mail-user=lauren.huet@uwa.edu.au
#-----------------


# Copy the file using rclone


echo "$SOURCE_DIR$FILE_PATH/$FILENAME" "$DEST_PATH$FILENAME" 
rclone copyto "$SOURCE_DIR$FILE_PATH/$FILENAME" "$DEST_PATH$FILENAME" --checksum --quiet
EOT
done <<< "$FILES"
