process ISOSEQ_REFINE {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::isoseq=4.3.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://quay.io/biocontainers/isoseq:4.3.0--h9ee0642_0' :
        'biocontainers/isoseq:4.3.0--h9ee0642_0' }"
    input:
    tuple val(meta), path(demux_bam), path(isoseq_primers)

    output:
    tuple val(meta), path("*.flnc.bam"), emit: flnc_bam
    tuple val(meta), path("*.consensusreadset.xml"), emit: consensusreadset
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    isoseq \\
        refine \\
        $args \\
        --log-level INFO \\
        --log-file ${prefix}.isoseq_refine.log \\
        --num-threads ${task.cpus} \\
        ${demux_bam} \\
        ${isoseq_primers} \\
        ${prefix}.flnc.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        isoseq: \$(echo \$(isoseq --version 2>&1) | sed 's/^.*isoseq //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.flnc.bam
    touch ${prefix}.consensusreadset.xml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        isoseq: \$(echo \$(isoseq --version 2>&1) | sed 's/^.*isoseq //; s/ .*\$//')
    END_VERSIONS
    """
}