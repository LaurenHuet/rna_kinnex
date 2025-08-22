process RUNQC {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(consensusreadset)

    output:
    tuple val(meta), path("qc_reports/*"), emit: qc_reports
    path "versions.yml"                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Create output directory
    mkdir -p qc_reports
    
    # Run QC reports using the specified path
    /software/projects/pawsey0964/smrtlink/smrtlink/smrtcmds/bin/runqc-reports $consensusreadset

    mv *.png *.json qc_reports

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        smrtlink-tools: \$(echo "13.0.0")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p qc_reports
    touch qc_reports/${prefix}_qc_report.html
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        smrtlink-tools: \$(echo "13.0.0")
    END_VERSIONS
    """
}