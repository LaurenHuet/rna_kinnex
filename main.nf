#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
RNA Kinnex Pipeline - PacBio IsoSeq Analysis
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Github : https://github.com/LaurenHuet/rna_kinnex
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { SKERA         } from './modules/local/skera'
include { LIMA          } from './modules/local/lima'
include { ISOSEQ_REFINE } from './modules/local/isoseq_refine'
include { RUNQC         } from './modules/local/runqc'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Function for simple samplesheet (backward compatibility)
def create_fastq_channel(LinkedHashMap row) {
    def meta = [:]
    meta.id = row.sample_id
    meta.single_end = true
    
    if (!file(row.bam_file).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> BAM file does not exist!\n${row.bam_file}"
    }
    
    return [meta, [file(row.bam_file)]]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
NAMED WORKFLOW FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow RNA_KINNEX {
    take:
    samplesheet     // channel: samplesheet read in from --input or --kinnex_samplesheet
    mas8_primers    // channel: path to MAS8 primers FASTA
    isoseq_primers  // channel: path to IsoSeq v2 primers FASTA
    sample_mapping  // channel: mapping file for renaming final outputs

    main:
    ch_versions = Channel.empty()

    //
    // COMBINE BAM files with primers for parallel processing
    //
    samplesheet
        .combine(mas8_primers)
        .map { meta, bam_file, primers_file ->
            return [meta, bam_file, primers_file]
        }
        .set { ch_skera_input }

    //
    // MODULE: Remove adapters with skera
    //
    SKERA (
        ch_skera_input
    )
    ch_versions = ch_versions.mix(SKERA.out.versions)

    //
    // COMBINE segmented BAM files with IsoSeq primers for parallel processing
    //
    SKERA.out.segmented_bam
        .combine(isoseq_primers)
        .map { meta, segmented_bam, primers_file ->
            return [meta, segmented_bam, primers_file]
        }
        .set { ch_lima_input }

    //
    // MODULE: Demultiplex with lima
    //
    LIMA (
        ch_lima_input
    )
    ch_versions = ch_versions.mix(LIMA.out.versions)

    //
    // PROCESS LIMA OUTPUT: Extract individual demultiplexed BAM files
    //
    LIMA.out.bam
        .transpose()  // This separates multiple BAM files into individual channel items
        .filter { meta, bam_file -> 
            // Only process files that contain actual barcode combinations, skip summary files
            bam_file.name.contains('IsoSeqX_bc') && bam_file.name.endsWith('.bam')
        }
        .map { meta, bam_file ->
            // Extract barcode information from filename for proper sample mapping
            def filename = bam_file.name
            def bc_match = filename =~ /IsoSeqX_(bc\d+)_5p--IsoSeqX_3p/
            def isoseq_bc = bc_match ? bc_match[0][1] : 'unknown'
            
            // Create new meta with barcode info for sample mapping
            def new_meta = meta.clone()
            new_meta.id = "${meta.plate_well}_${meta.file_bcm_code}_${isoseq_bc}"
            new_meta.isoseq_bc = isoseq_bc
            new_meta.lima_filename = filename
            
            return [new_meta, bam_file]
        }
        .set { ch_demux_bams }

    //
    // GROUP SAMPLES BY BARCODE COMBINATION AND ADD CONCATENATED FISH NAMES
    //
    if (sample_mapping) {
        // Read the sample mapping file and group by barcode combination
        sample_mapping
            .splitText()
            .map { line ->
                def parts = line.trim().split('\t')
                if (parts.size() >= 2) {
                    return [parts[0], parts[1]]  // [pattern, fish_name]
                }
            }
            .filter { it != null }
            .groupTuple(by: 0)  // Group by pattern (barcode combination)
            .map { pattern, fish_names ->
                // Concatenate multiple tissue names if they share the same barcode
                def combined_name = fish_names.sort().join('_')  // Sort for consistent naming
                return [pattern, combined_name]
            }
            .set { ch_mapping }

        // Apply combined sample names to demux BAMs
        ch_demux_bams
            .map { meta, bam_file ->
                def plate_bcm = "${meta.plate_well}_${meta.file_bcm_code}"
                def isoseq_bc = meta.isoseq_bc
                return [meta, bam_file, plate_bcm, isoseq_bc]
            }
            .combine(ch_mapping)
            .filter { meta, bam_file, plate_bcm, isoseq_bc, pattern, combined_fish_name ->
                def expected_pattern = "${plate_bcm}--IsoSeqX_${isoseq_bc}"
                return pattern == expected_pattern
            }
            .map { meta, bam_file, plate_bcm, isoseq_bc, pattern, combined_fish_name ->
                // Update meta with combined fish sample name
                def new_meta = meta.clone()
                new_meta.fish_sample = combined_fish_name
                new_meta.id = "${combined_fish_name}_${plate_bcm}_${isoseq_bc}"
                new_meta.original_id = meta.id
                new_meta.tissue_count = combined_fish_name.split('_').findAll { it.contains('R_KL') }.size()
                
                return [new_meta, bam_file]
            }
            .set { ch_demux_bams_with_fish_names }
    } else {
        ch_demux_bams.set { ch_demux_bams_with_fish_names }
    }

    //
    // COMBINE demultiplexed BAM files (with fish names) with IsoSeq primers for parallel processing
    //
    ch_demux_bams_with_fish_names
        .combine(isoseq_primers)
        .map { meta, demux_bam, primers_file ->
            return [meta, demux_bam, primers_file]
        }
        .set { ch_isoseq_input }

    //
    // MODULE: Refine reads with isoseq (now with combined fish sample names in meta.id)
    //
    ISOSEQ_REFINE (
        ch_isoseq_input
    )
    ch_versions = ch_versions.mix(ISOSEQ_REFINE.out.versions)

    //
    // MODULE: Run QC reports (now with combined fish sample names in filenames)
    //
    RUNQC (
        ISOSEQ_REFINE.out.consensusreadset
    )
    ch_versions = ch_versions.mix(RUNQC.out.versions)

    emit:
    segmented_bam = SKERA.out.segmented_bam
    demux_bam     = ch_demux_bams_with_fish_names
    flnc_bam      = ISOSEQ_REFINE.out.flnc_bam
    qc_reports    = RUNQC.out.qc_reports
    versions      = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
RUN ALL WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {
    // Input validation
    if (!params.input && !params.kinnex_samplesheet) {
        exit 1, 'Either --input or --kinnex_samplesheet must be specified!'
    }
    
    if (params.input && params.kinnex_samplesheet) {
        exit 1, 'Please specify either --input OR --kinnex_samplesheet, not both!'
    }

    // Handle Kinnex samplesheet format
    if (params.kinnex_samplesheet) {
        if (!params.data_dir) {
            exit 1, 'When using --kinnex_samplesheet, --data_dir must also be specified!'
        }
        
        // Create sample mapping for post-demultiplexing file renaming
        Channel
            .fromPath(params.kinnex_samplesheet, checkIfExists: true)
            .splitCsv(header: true, sep: ',')
            .map { row -> 
                def bc_mapping = [
                    'BC01': 'bcM0001',
                    'BC02': 'bcM0002', 
                    'BC03': 'bcM0003',
                    'BC04': 'bcM0004'
                ]
                def bcm_code = bc_mapping[row.kinnex_adapter_bc]
                // Create the pattern that matches our processing pipeline
                def lima_pattern = "${row.plate_well}_${bcm_code}--IsoSeqX_${row.isoseq_primer_bc.toLowerCase()}"
                return "${lima_pattern}\t${row.samples_in_pool}"
            }
            .collectFile(name: 'sample_mapping.txt', newLine: true)
            .set { ch_sample_mapping }
        
        // Process each BAM file individually
        def bam_file_paths = []
        file("${params.data_dir}/*/*.bam").each { bam_file ->
            if (bam_file.name.contains('bcM') || bam_file.name.contains('bc2015')) {
                bam_file_paths.add(bam_file.toString())
            }
        }
        
        Channel
            .fromList(bam_file_paths)
            .map { bam_path ->
                def bam_file = file(bam_path)
                def plate_well = bam_file.parent.name
                def filename = bam_file.name
                def bcm_match = filename =~ /\.(bcM\d{4}|bc\d{4})\./
                def file_bcm_code = bcm_match ? bcm_match[0][1] : 'unknown'
                
                def meta = [:]
                meta.id = "${plate_well}_${file_bcm_code}"
                meta.plate_well = plate_well
                meta.file_bcm_code = file_bcm_code
                meta.original_filename = filename
                
                def reverse_bc_mapping = [
                    'bcM0001': 'BC01',
                    'bcM0002': 'BC02',
                    'bcM0003': 'BC03',
                    'bcM0004': 'BC04'
                ]
                def kinnex_adapter_bc = reverse_bc_mapping[file_bcm_code]
                meta.kinnex_adapter_bc = kinnex_adapter_bc
                
                return [meta, bam_file]
            }
            .set { ch_samplesheet }
    }
    // Handle simple samplesheet format (backward compatibility)
    else {
        Channel
            .fromPath(params.input, checkIfExists: true)
            .splitCsv(header: true, sep: ',')
            .map { create_fastq_channel(it) }
            .set { ch_samplesheet }
            
        ch_sample_mapping = Channel.empty()
    }

    // Debug: Show what BAM files are being processed
    ch_samplesheet.view { "Processing BAM: ${it[0].id} -> ${it[1].name} (Contains samples with ${it[0].kinnex_adapter_bc} adapter)" }

    // Input channels for primer files
    mas8_primers_ch = Channel.fromPath("${projectDir}/scripts/mas8_primers.fasta", checkIfExists: true)
    isoseq_primers_ch = Channel.fromPath("${projectDir}/scripts/IsoSeq_v2_primers_12.fasta", checkIfExists: true)

    // Run the main workflow
    RNA_KINNEX (
        ch_samplesheet,
        mas8_primers_ch,
        isoseq_primers_ch,
        ch_sample_mapping
    )
}