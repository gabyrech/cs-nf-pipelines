// part A
process GATK_STATS_A {

  tag "sampleID"

  cpus 1
  memory 15.GB
  time '24:00:00'
  clusterOptions '-q batch'

  container 'broadinstitute/gatk:4.2.4.1'
  file(params.ref_fai)

  input:
  tuple val(sampleID), file(reord_sorted_bam)
  tuple val(sampleID), file(reord_sorted_bai)

  output:
  tuple val(sampleID), file("*gatk_temp1*"), emit: gatk_1
  tuple val(sampleID), file("*gatk_temp4*"), emit: gatk_4

  when:
  params.gen_org == "human"

  script:
  log.info "----- Human GATK Coverage Stats, Part 1 Running on: ${sampleID} -----"
  """
  gatk DepthOfCoverage \
  -R ${params.ref_fa} \
  --output-format TABLE \
  -O ${sampleID}_gatk_temp1.txt \
  -I ${reord_sorted_bam} \
  -L  ${params.probes} \
  --omit-per-sample-statistics \
  --omit-interval-statistics \
  --omit-locus-table \

  gatk DepthOfCoverage \
  -R ${params.ref_fa} \
  --output-format TABLE \
  -O ${sampleID}_gatk_temp4.txt \
  -I ${reord_sorted_bam} \
  -L ${params.ctp_genes} \
  --omit-per-sample-statistics \
  --omit-interval-statistics \
  --omit-locus-table \
  """
  }

// part B
process GATK_STATS_B {

  tag "sampleID"

  cpus 1
  memory 15.GB
  time '24:00:00'
  clusterOptions '-q batch'

  container 'python_2_7_3'

  publishDir "${params.pubdir}/${ params.organize_by=='sample' ? sampleID : 'gatk' }", pattern: "*.*", mode:'copy'

  input:
  tuple val(sampleID), file(gatk_1)
  tuple val(sampleID), file(gatk_4)

  output:
  file "*CCP_interval_avg_median_coverage.bed"
  file "*exome_interval_avg_median_coverage.bed"
  tuple val(sampleID), file("*CP_interval_avg_median_coverage.bed")

  when:
  params.gen_org == "human"

  script:
  log.info "-----Human GATK Coverage Stats, Part 2 Running on: ${sampleID} -----"

  """

  ${params.gatk_form} ${sampleID}_gatk_temp1.txt ${sampleID}_gatk_temp2.txt ${sampleID}_gatk_temp3.txt ${params.probes}

  ${params.gatk_form} ${sampleID}_gatk_temp4.txt ${sampleID}_gatk_temp5.txt ${sampleID}_gatk_temp6.txt ${params.ctp_genes}

  python ${params.cov_calc} ${sampleID}_gatk_temp3.txt ${sampleID}_exome_interval_avg_median_coverage.bed

  python ${params.cov_calc} ${sampleID}_gatk_temp6.txt ${sampleID}_CCP_interval_avg_median_coverage.bed

  """
  }
