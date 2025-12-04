process LIMA {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::lima=2.13.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://quay.io/biocontainers/lima:2.13.0--h9ee0642_0' :
        'biocontainers/lima:2.13.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(segmented_bam), path(isoseq_primers)

    output:
    tuple val(meta), path("*.demux.IsoSeqX_bc*_5p--IsoSeqX_3p.bam"), emit: bam
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: '--isoseq --peek-guess'
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    lima \\
        $args \\
        --log-level INFO \\
        --log-file ${prefix}.lima.log \\
        --num-threads ${task.cpus} \\
        ${segmented_bam} \\
        ${isoseq_primers} \\
        ${prefix}.demux.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        lima: \$(echo \$(lima --version 2>&1) | sed 's/^.*lima //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.demux.IsoSeqX_bc01_5p--IsoSeqX_3p.bam
    touch ${prefix}.demux.IsoSeqX_bc02_5p--IsoSeqX_3p.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        lima: \$(echo \$(lima --version 2>&1) | sed 's/^.*lima //; s/ .*\$//')
    END_VERSIONS
    """
}