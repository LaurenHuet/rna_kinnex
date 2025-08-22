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

def create_fastq_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id         = row.sample_id
    meta.single_end = true

    // add path(s) of the fastq file(s) to the meta map
    def fastq_meta = []
    if (!file(row.bam_file).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> BAM file does not exist!\n${row.bam_file}"
    }
    fastq_meta = [ meta, [ file(row.bam_file) ] ]
    return fastq_meta
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOW FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow RNA_KINNEX {
    
    take:
    samplesheet     // channel: samplesheet read in from --input
    mas8_primers    // channel: path to MAS8 primers FASTA
    isoseq_primers  // channel: path to IsoSeq v2 primers FASTA
    
    main:
    
    ch_versions = Channel.empty()
    
    //
    // MODULE: Remove adapters with skera
    //
    SKERA (
        samplesheet,
        mas8_primers
    )
    ch_versions = ch_versions.mix(SKERA.out.versions)
    
    //
    // MODULE: Demultiplex with lima
    //
    LIMA (
        SKERA.out.segmented_bam,
        isoseq_primers
    )
    ch_versions = ch_versions.mix(LIMA.out.versions)
    
    //
    // MODULE: Refine reads with isoseq
    //
    ISOSEQ_REFINE (
        LIMA.out.bam,
        isoseq_primers
    )
    ch_versions = ch_versions.mix(ISOSEQ_REFINE.out.versions)
    
    //
    // MODULE: Run QC reports
    //
    RUNQC (
        ISOSEQ_REFINE.out.consensusreadset
    )
    ch_versions = ch_versions.mix(RUNQC.out.versions)
    
    emit:
    segmented_bam = SKERA.out.segmented_bam
    demux_bam     = LIMA.out.bam
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
    
    // Read in samplesheet, validate and stage input files
    if(params.input) {
        Channel
            .fromPath(params.input, checkIfExists: true)
            .splitCsv(header:true, sep:',')
            .map { create_fastq_channel(it) }
            .set { ch_samplesheet }
    } else {
        exit 1, 'Input samplesheet not specified!'
    }
    
    // Input channels
    mas8_primers_ch = Channel.fromPath("${projectDir}/scripts/mas8_primers.fasta", checkIfExists: true)
    isoseq_primers_ch = Channel.fromPath("${projectDir}/scripts/IsoSeq_v2_primers_12.fasta", checkIfExists: true)
    
    // Run the main workflow
    RNA_KINNEX (
        ch_samplesheet,
        mas8_primers_ch,
        isoseq_primers_ch
    )
}