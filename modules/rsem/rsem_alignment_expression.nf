process RSEM_ALIGNMENT_EXPRESSION {
  tag "$sampleID"

  cpus 12
  memory { 60.GB * task.attempt }
  time { 24.h * task.attempt }
  errorStrategy 'retry'
  maxRetries 1

    container 'quay.io/jaxcompsci/rsem_bowtie2_star:0.1.0'

  publishDir "${params.pubdir}/${ params.organize_by=='sample' ? sampleID+'/stats' : 'rsem' }", pattern: "*stats", mode:'copy', enabled: params.rsem_aligner == "bowtie2"
  publishDir "${params.pubdir}/${ params.organize_by=='sample' ? sampleID : 'rsem' }", pattern: "*results*", mode:'copy'
  publishDir "${params.pubdir}/${ params.organize_by=='sample' ? sampleID+'/bam' : 'rsem' }", pattern: "*genome.sorted.ba*", mode:'copy'
  publishDir "${params.pubdir}/${ params.organize_by=='sample' ? sampleID+'/bam' : 'rsem' }", pattern: "*transcript.sorted.ba*", mode:'copy'

  input:
  tuple val(sampleID), file(reads)
  file(rsem_ref_files)

  output:
  file "*stats"
  file "*results*"
  tuple val(sampleID), file("rsem_aln_*.stats"), emit: rsem_stats
  tuple val(sampleID), file("*genes.results"), emit: rsem_genes
  tuple val(sampleID), file("*isoforms.results"), emit: rsem_isoforms
  tuple val(sampleID), file("*.genome.bam"), emit: bam
  tuple val(sampleID), file("*.transcript.bam"), emit: transcript_bam
  tuple val(sampleID), path("*.genome.sorted.bam"), path("*.genome.sorted.bam.bai"), emit: sorted_genomic_bam
  tuple val(sampleID), path("*.transcript.sorted.bam"), path("*.transcript.sorted.bam.bai"), emit: sorted_transcript_bam
 
  script:

  if (params.read_prep == "reverse_stranded") {
    prob="--forward-prob 0"
  }

  if (params.read_prep == "forward_stranded") {
    prob="--forward-prob 1"
  }

  if (params.read_prep == "non_stranded") {
    prob="--forward-prob 0.5"
  }

  if (params.read_type == "PE"){
    frag=""
    stype="--paired-end"
    trimmedfq="${reads[0]} ${reads[1]}"
  }
  if (params.read_type == "SE"){
    frag="--fragment-length-mean 280 --fragment-length-sd 50"
    stype=""
    trimmedfq="${reads[0]}"
  }
  if (params.rsem_aligner == "bowtie2"){
    outbam="--output-genome-bam --sort-bam-by-coordinate"
    seed_length="--seed-length ${params.seed_length}"
    sort_command=''
    index_command=''
  }
  if (params.rsem_aligner == "star") {
    outbam="--star-output-genome-bam --sort-bam-by-coordinate"
    seed_length=""
    sort_command="samtools sort -@ ${task.cpus} -m ${task.memory.giga}G -o ${sampleID}.STAR.genome.sorted.bam ${sampleID}.STAR.genome.bam"
    index_command="samtools index ${sampleID}.STAR.genome.sorted.bam"
  }

  """
  rsem-calculate-expression -p $task.cpus \
  ${prob} \
  ${stype} \
  ${frag} \
  --${params.rsem_aligner} \
  --append-names \
  ${seed_length} \
  ${outbam} \
  ${trimmedfq} \
  ${params.rsem_ref_prefix} \
  ${sampleID} \
  2> rsem_aln_${sampleID}.stats

  ${sort_command}

  ${index_command}
  """
}