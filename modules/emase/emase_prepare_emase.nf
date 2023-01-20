process EMASE_PREPARE_EMASE {

    // give a fasta or group of fastas, gtf or group of gtfs, and a haplotype list 
    // 1. generate a hybrid genome
    // 2. generate transcript list
    // 3. generate gene to transcript map
    // 4. generate bowtie index. 

    // NOTE: Transcript lists are 'pooled' but can be incomplete for certain haplotypes. 
    //       Missing transcripts in haplotypes will cause errors in `run-emase`. 
    //       Helper script `clean_transcript_info.py` can be used to add missing transcripts. 

    cpus 1
    memory {15.GB * task.attempt}
    time {24.hour * task.attempt}
    errorStrategy 'retry' 
    maxRetries 1

    container 'quay.io/jaxcompsci/emase_gbrs_alntools:3ac8573'

    publishDir "${params.pubdir}/emase", pattern: '*.fa', mode:'copy'
    publishDir "${params.pubdir}/emase", pattern: '*.info', mode:'copy'
    publishDir "${params.pubdir}/emase", pattern: '*.tsv', mode:'copy'
    publishDir "${params.pubdir}/emase/bowtie", pattern: "*.ebwt", mode:'copy'

    output:
    path("*.fa"), emit: pooled_transcript_fasta
    path("*.info"), emit: pooled_transcript_info
    path("*.tsv"), emit: pooled_gene_to_transcripts
    path("*.ebwt"), emit: pooled_bowtie_index

    script:
    """
    prepare-emase -G ${params.genome_file_list} -g ${params.gtf_file_list} -s ${params.haplotype_list} -o ./ -m
    """

    stub:
    """
    touch emase.pooled.transcripts.fa
    touch emase.pooled.transcripts.info
    touch emase.gene2transcripts.tsv
    touch bowtie.transcripts.4.ebwt
    touch bowtie.transcripts.3.ebwt
    touch bowtie.transcripts.2.ebwt
    touch bowtie.transcripts.1.ebwt
    touch bowtie.transcripts.rev.2.ebwt
    touch bowtie.transcripts.rev.1.ebwt
    """

}