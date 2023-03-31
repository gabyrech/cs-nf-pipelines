process CHAIN_FILTER_READS {
  tag "$sampleID"

  cpus 2
  memory 4.GB
  time = '10:00:00'

  publishDir "${params.pubdir}/${ params.organize_by=='sample' ? sampleID+'/stats' : 'gatk' }", pattern: "*.log", mode: 'copy'
  container 'broadinstitute/gatk:4.2.4.1'

  input:
  tuple val(sampleID), file(bam_sort_mm10), file(ReadName_unique)
  

  output:
  tuple val(sampleID), file("*.tmp2.mm10.ba*")
  tuple val(sampleID), file("*_FilterSamReads.log"), emit: filterReads_log

  when: params.chain != null

  script:
  log.info "----- Filtering list to unique name on ${sampleID} -----"
  """
  gatk FilterSamReads \
  -I ${bam_sort_mm10[0]} \
  -RLF ReadName_unique \
  --FILTER excludeReadList \
  --VALIDATION_STRINGENCY LENIENT \
  -O ${sampleID}.tmp2.mm10.bam \
  > ${sampleID}_FilterSamReads.log 2>&1
  """
}
