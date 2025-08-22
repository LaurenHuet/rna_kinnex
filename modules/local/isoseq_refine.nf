process ISOSEQ_REFINE {
    tag "$meta.id"
    label 'process_high_memory'
    
    conda "bioconda::isoseq=4.3.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://quay.io/biocontainers/isoseq:4.3.0--h9ee0642_0' :
        'biocontainers/isoseq:4.3.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(bam)
    path isoseq_primers

    output:
    tuple val(meta), path("*.flnc.bam")          , emit: flnc_bam
    tuple val(meta), path("*.bam.pbi")                    , emit: pbi
    tuple val(meta), path("*.consensusreadset.xml")       , emit: consensusreadset
    tuple val(meta), path("*.filter_summary.report.json") , emit: summary
    tuple val(meta), path("*.report.csv")                 , emit: report
    path  "versions.yml"                                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    ls *.bam > input_bams.fofn

    isoseq refine \\
        input_bams.fofn \\
        $isoseq_primers \\
        ${prefix}.flnc.bam \\
        --require-polya \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        isoseq: \$(isoseq --version 2>&1 | grep -o 'isoseq [0-9.]*' | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.flnc.bam
    touch ${prefix}.consensusreadset.xml
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        isoseq: \$(isoseq --version 2>&1 | grep -o 'isoseq [0-9.]*' | cut -d' ' -f2)
    END_VERSIONS
    """
}