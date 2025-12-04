process SKERA {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::pbskera=1.4.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://quay.io/biocontainers/pbskera:1.4.0--hdfd78af_0' :
        'biocontainers/pbskera:1.4.0--hdfd78af_0' }"

    input:
    tuple val(meta), path(input_hifi), path(mas8_primers)

    output:
    tuple val(meta), path("*.segmented.skera.bam"), emit: segmented_bam
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    skera \\
        split \\
        $args \\
        --log-level INFO \\
        --log-file ${prefix}.skera.log \\
        ${input_hifi} \\
        ${mas8_primers} \\
        ${prefix}.segmented.skera.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        skera: \$(echo \$(skera --version 2>&1) | sed 's/^.*skera //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.segmented.skera.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        skera: \$(echo \$(skera --version 2>&1) | sed 's/^.*skera //; s/ .*\$//')
    END_VERSIONS
    """
}