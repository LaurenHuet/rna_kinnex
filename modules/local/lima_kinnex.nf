process LIMA_KINNEX {
    tag "$meta.id"
    label 'process_high'
    
    conda "bioconda::lima=2.13.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://quay.io/biocontainers/lima:2.13.0--h9ee0642_0' :
        'biocontainers/lima:2.13.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(segmented_bam)
    path isoseq_primers

    output:
    tuple val(meta), path("*.counts") , emit: counts
    tuple val(meta), path("*.report") , emit: report
    tuple val(meta), path("*.summary"), emit: summary
    tuple val(meta), path("*--*.bam")              , optional: true, emit: bam
    tuple val(meta), path("*--*.bam.pbi")          , optional: true, emit: pbi
    tuple val(meta), path("*--*.{fa, fasta}")      , optional: true, emit: fasta
    tuple val(meta), path("*--*.{fa.gz, fasta.gz}"), optional: true, emit: fastagz
    tuple val(meta), path("*--*.fastq")            , optional: true, emit: fastq
    tuple val(meta), path("*--*.fastq.gz")         , optional: true, emit: fastqgz
    tuple val(meta), path("*--*.xml")              , optional: true, emit: xml
    tuple val(meta), path("*--*.json")             , optional: true, emit: json
    tuple val(meta), path("*--*.clips")            , optional: true, emit: clips
    tuple val(meta), path("*--*.guess")            , optional: true, emit: guess
    path "versions.yml"               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if( "$segmented_bam" == "${prefix}.bam" )      error "Input and output names are the same, set prefix in module configuration"

    """
    OUT_EXT=""

    if [[ $segmented_bam =~ bam\$ ]]; then
        OUT_EXT="bam"
    elif [[ $segmented_bam =~ fasta\$ ]]; then
        OUT_EXT="fasta"
    elif [[ $segmented_bam =~ fasta.gz\$ ]]; then
        OUT_EXT="fasta.gz"
    elif [[ $segmented_bam =~ fastq\$ ]]; then
        OUT_EXT="fastq"
    elif [[ $segmented_bam =~ fastq.gz\$ ]]; then
        OUT_EXT="fastq.gz"
    fi

    # Run lima with original prefix
    lima \\
        $segmented_bam \\
        $isoseq_primers \\
        ${prefix}_temp.\$OUT_EXT \\
        -j $task.cpus \\
        $args

    # Create sample mapping file from meta information
    cat > sample_mapping.txt << 'EOF'
${meta.sample_mapping.collect { isoseq_bc, sample_name -> "${isoseq_bc}\t${sample_name}" }.join('\n')}
EOF

    # Rename files according to sample mapping
    for temp_file in ${prefix}_temp--*.bam; do
        if [[ -f "\$temp_file" ]]; then
            # Extract barcode from filename (e.g., IsoSeqX_bc01 from temp--IsoSeqX_bc01.bam)
            barcode=\$(basename "\$temp_file" | sed 's/.*--\\(IsoSeqX_bc[0-9]\\+\\).*/\\1/' | sed 's/IsoSeqX_bc/BC/')
            
            # Pad barcode to BC## format
            if [[ \$barcode =~ ^BC[0-9]\$ ]]; then
                barcode="BC0\${barcode#BC}"
            fi
            
            # Look up sample name from mapping
            sample_name=\$(grep "^\$barcode" sample_mapping.txt | cut -f2)
            
            if [[ -n "\$sample_name" ]]; then
                # Rename file with actual sample name
                new_name="\${sample_name}.\$OUT_EXT"
                mv "\$temp_file" "\$new_name"
                
                # Also rename corresponding .pbi file if it exists
                pbi_file="\${temp_file}.pbi"
                if [[ -f "\$pbi_file" ]]; then
                    mv "\$pbi_file" "\${new_name}.pbi"
                fi
            else
                # Keep original name if no mapping found
                mv "\$temp_file" "\$(basename "\$temp_file" | sed "s/${prefix}_temp--//")"
            fi
        fi
    done

    # Rename other output files
    for file in ${prefix}_temp.*; do
        if [[ -f "\$file" && ! "\$file" =~ --.*bam ]]; then
            new_name=\$(basename "\$file" | sed "s/${prefix}_temp/${prefix}/")
            mv "\$file" "\$new_name"
        fi
    done

    # Clean up
    rm -f sample_mapping.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        lima: \$( lima --version | head -n1 | sed 's/lima //g' | sed 's/ (.\\+//g' )
    END_VERSIONS
    """
}