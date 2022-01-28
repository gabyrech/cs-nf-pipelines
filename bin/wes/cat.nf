process CAT_SNP_INDEL{
  """
  cat !{snps_filt} > !{sampleID}_full_anno_snp.vcf
  cat !{indels_filt} > !{sampleID}_full_anno_indel.vcf
  """
}
process CAT_INDEL_HUMAN{
  tag "sampleID"

  cpus 1
  memory 2.GB
  time '00:10:00'
  clusterOptions '-q batch' 
  
  container 'gatk-4.1.6.0_samtools-1.3.1_snpEff_4.3_vcftools_bcftools.sif'

  input:
  tuple val(sampleID), file(vcf)
  
  output:
  tuple	val(sampleID), file(vcf), emit: vcf

  script:
  // the pl in here needs to be discovered. this will happen when making the container cook book
  """
  cat ${vcf} | /snpEff_v4_3/snpEff/scripts/vcfEffOnePerLine.pl > ${sampleID}indel_oneperline.vcf
  """
}
