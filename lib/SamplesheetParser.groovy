#!/usr/bin/env nextflow

import java.nio.file.Path
import java.nio.file.Paths
import groovy.json.JsonBuilder
import nextflow.Nextflow

class SamplesheetParser {

    public static ArrayList parseKinnexSamplesheet(Path samplesheet_file) {
        
        def parsed_samples = []
        def csv_lines = samplesheet_file.readLines()
        def header = csv_lines[0].split(',')
        
        // Expected headers for the complex samplesheet
        def expected_headers = [
            'plate_well', 'sequencing_sample_id', 'library_type', 
            'kinnex_pool', 'kinnex_adapter_bc', 'samples_in_pool', 'isoseq_primer_bc'
        ]
        
        // Validate headers
        if (!expected_headers.every { header.contains(it) }) {
            Nextflow.error("Invalid samplesheet format. Expected headers: ${expected_headers.join(', ')}")
        }
        
        // Create mapping dictionaries
        def plate_well_to_samples = [:]
        def bcm_to_bc_mapping = [
            'bcM0001': 'BC01',
            'bcM0002': 'BC02', 
            'bcM0003': 'BC03',
            'bcM0004': 'BC04'
        ]
        
        // Parse each line (skip header)
        for (int i = 1; i < csv_lines.size(); i++) {
            def line = csv_lines[i]
            if (line.trim()) {
                def fields = line.split(',')
                def row = [:]
                
                // Map fields to column names
                header.eachWithIndex { col, idx ->
                    if (idx < fields.size()) {
                        row[col.trim()] = fields[idx].trim()
                    }
                }
                
                def plate_well = row['plate_well']
                def kinnex_adapter = row['kinnex_adapter_bc']
                def sample_name = row['samples_in_pool']
                def isoseq_bc = row['isoseq_primer_bc']
                
                // Initialize plate well mapping if not exists
                if (!plate_well_to_samples.containsKey(plate_well)) {
                    plate_well_to_samples[plate_well] = [:]
                }
                
                // Initialize kinnex adapter mapping if not exists
                if (!plate_well_to_samples[plate_well].containsKey(kinnex_adapter)) {
                    plate_well_to_samples[plate_well][kinnex_adapter] = [:]
                }
                
                // Store the sample mapping
                plate_well_to_samples[plate_well][kinnex_adapter][isoseq_bc] = sample_name
            }
        }
        
        return [plate_well_to_samples, bcm_to_bc_mapping]
    }
    
    public static ArrayList createChannelFromKinnexSamplesheet(Path samplesheet_file, String data_dir) {
        
        def (plate_well_to_samples, bcm_to_bc_mapping) = parseKinnexSamplesheet(samplesheet_file)
        def channel_data = []
        
        // For each plate well, find the corresponding BAM files
        plate_well_to_samples.each { plate_well, kinnex_pools ->
            
            // Look for BAM files in the data directory structure
            def well_dir = Paths.get(data_dir, plate_well, "hifi")
            
            if (well_dir.toFile().exists()) {
                // Find all BAM files in this well directory
                well_dir.toFile().listFiles().each { bam_file ->
                    if (bam_file.name.endsWith('.bam') && !bam_file.name.contains('unassigned')) {
                        
                        // Extract bcM code from filename (e.g., bcM0001 from m84154_250728_084101_s1.hifi_reads.bcM0001.bam)
                        def bcm_match = bam_file.name =~ /\.bcM(\d{4})\./
                        if (bcm_match) {
                            def bcm_code = "bcM${bcm_match[0][1]}"
                            def bc_code = bcm_to_bc_mapping[bcm_code]
                            
                            if (bc_code && kinnex_pools.containsKey(bc_code)) {
                                // Create meta map for this BAM file
                                def meta = [:]
                                meta.id = "${plate_well}_${bcm_code}"
                                meta.plate_well = plate_well
                                meta.kinnex_adapter = bc_code
                                meta.bcm_code = bcm_code
                                meta.sample_mapping = kinnex_pools[bc_code]
                                meta.single_end = true
                                
                                // Add to channel data
                                channel_data.add([meta, [bam_file.toPath()]])
                            }
                        }
                    }
                }
            } else {
                Nextflow.error("Directory not found: ${well_dir}")
            }
        }
        
        return channel_data
    }
}