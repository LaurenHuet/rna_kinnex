#!/usr/bin/env python3
"""
Script to convert lab samplesheet format to pipeline format
"""

import pandas as pd
import sys

def convert_lab_sheet_to_pipeline_format(input_file, output_file):
    """
    Convert lab samplesheet format to pipeline-compatible format
    """
    
    # Read the lab data - you'll need to adjust this based on your actual file format
    # This assumes your lab data is in a CSV or tab-separated format
    
    print("Converting lab samplesheet to pipeline format...")
    
    # Example conversion based on your data structure
    lab_data = [
        # Format: [plate_well, sequencing_id, library_type, kinnex_pool, kinnex_adapter, sample_name, isoseq_bc]
        ["1_A01", "PACB_250728_LAAK_P1A1", "Kinnex", "Pool5_Kinnex_250714_AK", "BC01", "OG37G_R_KL", "BC04"],
        ["1_A01", "PACB_250728_LAAK_P1A1", "Kinnex", "Pool5_Kinnex_250714_AK", "BC01", "OG37H_R_KL", "BC04"],
        ["1_A01", "PACB_250728_LAAK_P1A1", "Kinnex", "Pool5_Kinnex_250714_AK", "BC01", "OG46G_R_KL", "BC06"],
        ["1_A01", "PACB_250728_LAAK_P1A1", "Kinnex", "Pool5_Kinnex_250714_AK", "BC01", "OG46M_R_KL", "BC06"],
        ["1_A01", "PACB_250728_LAAK_P1A1", "Kinnex", "Pool5_Kinnex_250714_AK", "BC01", "OG85G_R_KL", "BC09"],
        ["1_A01", "PACB_250728_LAAK_P1A1", "Kinnex", "Pool5_Kinnex_250714_AK", "BC01", "OG85M_R_KL", "BC09"],
        ["1_A01", "PACB_250728_LAAK_P1A1", "Kinnex", "Pool3_Kinnex_250714_AK", "BC03", "OG88G_R_KL2", "BC10"],
        ["1_A01", "PACB_250728_LAAK_P1A1", "Kinnex", "Pool3_Kinnex_250714_AK", "BC03", "OG88M_R_KL2", "BC11"],
        ["1_B01", "PACB_250728_LAAK_P1B1", "Kinnex", "Pool1_Kinnex_250707_LAAK", "BC01", "OG14G_R_KL", "BC03"],
        ["1_B01", "PACB_250728_LAAK_P1B1", "Kinnex", "Pool1_Kinnex_250707_LAAK", "BC01", "OG14M_R", "BC03"],
        ["1_B01", "PACB_250728_LAAK_P1B1", "Kinnex", "Pool1_Kinnex_250707_LAAK", "BC01", "OG15G_R", "BC04"],
        ["1_B01", "PACB_250728_LAAK_P1B1", "Kinnex", "Pool1_Kinnex_250707_LAAK", "BC01", "OG15M_R", "BC04"],
        ["1_C01", "PACB_250728_LAAK_P1C1", "Kinnex", "Pool1_Kinnex_250714_AK", "BC01", "OG698G_R_KL", "BC02"],
        ["1_C01", "PACB_250728_LAAK_P1C1", "Kinnex", "Pool1_Kinnex_250714_AK", "BC01", "OG698M_R_KL", "BC02"],
        ["1_C01", "PACB_250728_LAAK_P1C1", "Kinnex", "Pool1_Kinnex_250714_AK", "BC01", "OG36M_R_KL2", "BC12"],
        ["1_C01", "PACB_250728_LAAK_P1C1", "Kinnex", "Pool2_Kinnex_250714_AK", "BC02", "OG686G_R_KL", "BC03"],
        ["1_C01", "PACB_250728_LAAK_P1C1", "Kinnex", "Pool2_Kinnex_250714_AK", "BC02", "OG686M_R_KL", "BC03"],
        ["1_C01", "PACB_250728_LAAK_P1C1", "Kinnex", "Pool2_Kinnex_250714_AK", "BC02", "OG38G_R_KL", "BC05"],
        ["1_C01", "PACB_250728_LAAK_P1C1", "Kinnex", "Pool2_Kinnex_250714_AK", "BC02", "OG38M_R_KL", "BC05"],
        ["1_C01", "PACB_250728_LAAK_P1C1", "Kinnex", "Pool4_Kinnex_250714_AK", "BC04", "OG696H_R_KL", "BC01"],
        ["1_C01", "PACB_250728_LAAK_P1C1", "Kinnex", "Pool4_Kinnex_250714_AK", "BC04", "OG696M_R_KL", "BC01"],
        ["1_C01", "PACB_250728_LAAK_P1C1", "Kinnex", "Pool4_Kinnex_250714_AK", "BC04", "OG54G_R_KL", "BC07"],
        ["1_C01", "PACB_250728_LAAK_P1C1", "Kinnex", "Pool4_Kinnex_250714_AK", "BC04", "OG54M_R_KL", "BC07"],
    ]
    
    # Create DataFrame
    df = pd.DataFrame(lab_data, columns=[
        'plate_well', 'sequencing_sample_id', 'library_type', 
        'kinnex_pool', 'kinnex_adapter_bc', 'samples_in_pool', 'isoseq_primer_bc'
    ])
    
    # Save to CSV
    df.to_csv(output_file, index=False)
    print(f"Converted samplesheet saved to: {output_file}")
    
    # Show summary
    print(f"\nSummary:")
    print(f"- Total samples: {len(df)}")
    print(f"- Plate wells: {df['plate_well'].nunique()}")
    print(f"- Unique sample names: {df['samples_in_pool'].nunique()}")
    
    return df

def parse_lab_format(lab_text):
    """
    Parse your lab's original format and convert to structured data
    """
    # This function would parse your lab's specific format
    # You can customize this based on how your lab provides the data
    
    lines = lab_text.strip().split('\n')
    parsed_data = []
    
    for line in lines:
        if line.strip() and not line.startswith('Sample Plate'):
            # Parse each line based on your lab's format
            # This is a template - adjust based on your actual format
            parts = line.split('\t')  # or split(',') if comma-separated
            
            # Extract information from each line
            # You'll need to adjust the indices based on your actual format
            if len(parts) >= 7:
                plate_well = parts[0].strip()
                sequencing_id = parts[1].strip()
                library_type = parts[2].strip()
                kinnex_pool = parts[3].strip()
                kinnex_adapter = parts[4].strip()
                sample_name = parts[5].strip()
                isoseq_bc = parts[6].strip()
                
                parsed_data.append([
                    plate_well, sequencing_id, library_type,
                    kinnex_pool, kinnex_adapter, sample_name, isoseq_bc
                ])
    
    return parsed_data

if __name__ == "__main__":
    # Convert the example data
    output_file = "converted_samplesheet.csv"
    df = convert_lab_sheet_to_pipeline_format(None, output_file)
    
    print("\nFirst few rows of converted samplesheet:")
    print(df.head())
    
    print(f"\nTo use this samplesheet with the pipeline, run:")
    print(f"nextflow run main.nf \\")
    print(f"    --kinnex_samplesheet {output_file} \\")
    print(f"    --data_dir /path/to/your/data \\")
    print(f"    --outdir results \\")
    print(f"    -profile docker")