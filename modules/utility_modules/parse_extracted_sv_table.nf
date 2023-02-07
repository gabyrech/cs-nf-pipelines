
process SNPSIFT_EXTRACT_AND_PARSE {

    // NOTE: This script is for the parsing of the 'SV' pipeline germline annotationed table from snpeff extractfields. 
    //       It is hard coded to the annotations used. 

    tag "$sampleID"

    cpus = 1
    memory = 6.GB
    time = '03:00:00'

    container 'quay.io/jaxcompsci/py3_perl_pylibs:v1'

    publishDir "${params.pubdir}/${ params.organize_by=='sample' ? sampleID : 'snpeff' }", pattern:"*.txt", mode:'copy'

    input:
    tuple val(sampleID), file(table)

    output:
    tuple val(sampleID), file("*.txt"), emit: txt

    script:

    """
    python ${projectDir}/bin/sv/split_annotations.py ${table} ${sampleID}_annotated_filtered_final_table.txt
    """
}

