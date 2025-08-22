process LIMA {
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
    tuple val(meta), path("*.bam")              , optional: true, emit: bam
    tuple val(meta), path("*.bam.pbi")          , optional: true, emit: pbi
    tuple val(meta), path("*.{fa, fasta}")      , optional: true, emit: fasta
    tuple val(meta), path("*.{fa.gz, fasta.gz}"), optional: true, emit: fastagz
    tuple val(meta), path("*.fastq")            , optional: true, emit: fastq
    tuple val(meta), path("*.fastq.gz")         , optional: true, emit: fastqgz
    tuple val(meta), path("*.xml")              , optional: true, emit: xml
    tuple val(meta), path("*.json")             , optional: true, emit: json
    tuple val(meta), path("*.clips")            , optional: true, emit: clips
    tuple val(meta), path("*.guess")            , optional: true, emit: guess
    path "versions.yml"               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if( "$segmented_bam" == "${prefix}.bam" )      error "Input and output names are the same, set prefix in module configuration"
    if( "$segmented_bam" == "${prefix}.fasta" )    error "Input and output names are the same, set prefix in module configuration"
    if( "$segmented_bam" == "${prefix}.fasta.gz" ) error "Input and output names are the same, set prefix in module configuration"
    if( "$segmented_bam" == "${prefix}.fastq" )    error "Input and output names are the same, set prefix in module configuration"
    if( "$segmented_bam" == "${prefix}.fastq.gz" ) error "Input and output names are the same, set prefix in module configuration"

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

    lima \\
        $segmented_bam \\
        $isoseq_primers \\
        $prefix.\$OUT_EXT \\
        -j $task.cpus \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        lima: \$( lima --version | head -n1 | sed 's/lima //g' | sed 's/ (.\\+//g' )
    END_VERSIONS
    """
}