#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// import modules
include {help} from "${projectDir}/bin/help/wes.nf"
include {param_log} from "${projectDir}/bin/log/wes.nf"
include {getLibraryId} from "${projectDir}/bin/shared/getLibraryId.nf"
include {extract_csv} from "${projectDir}/bin/shared/extract_csv.nf"
include {ARIA_DOWNLOAD} from "${projectDir}/modules/utility_modules/aria_download"
include {CONCATENATE_READS_PE} from "${projectDir}/modules/utility_modules/concatenate_reads_PE"
include {CONCATENATE_READS_SE} from "${projectDir}/modules/utility_modules/concatenate_reads_SE"
include {CONCATENATE_READS_SAMPLESHEET} from "${projectDir}/modules/utility_modules/concatenate_reads_sampleSheet"
include {BWA_MEM} from "${projectDir}/modules/bwa/bwa_mem"
include {SAMTOOLS_INDEX} from "${projectDir}/modules/samtools/samtools_index"
include {READ_GROUPS} from "${projectDir}/modules/utility_modules/read_groups"
include {QUALITY_STATISTICS} from "${projectDir}/modules/utility_modules/quality_stats"
include {AGGREGATE_STATS} from "${projectDir}/modules/utility_modules/aggregate_stats_wes"
include {COSMIC_ANNOTATION;
        COSMIC_ANNOTATION as COSMIC_ANNOTATION_SNP;
        COSMIC_ANNOTATION as COSMIC_ANNOTATION_INDEL} from "${projectDir}/modules/cosmic/cosmic_annotation"
include {PICARD_SORTSAM} from "${projectDir}/modules/picard/picard_sortsam"
include {PICARD_MARKDUPLICATES} from "${projectDir}/modules/picard/picard_markduplicates"
include {PICARD_COLLECTHSMETRICS} from "${projectDir}/modules/picard/picard_collecthsmetrics"
include {SNPEFF;
         SNPEFF as SNPEFF_SNP;
         SNPEFF as SNPEFF_INDEL} from "${projectDir}/modules/snpeff_snpsift/snpeff_snpeff"
include {SNPEFF_ONEPERLINE as SNPEFF_ONEPERLINE_SNP;
         SNPEFF_ONEPERLINE as SNPEFF_ONEPERLINE_INDEL} from "${projectDir}/modules/snpeff_snpsift/snpeff_oneperline"
include {SNPSIFT_EXTRACTFIELDS} from "${projectDir}/modules/snpeff_snpsift/snpsift_extractfields"
include {SNPSIFT_DBNSFP as SNPSIFT_DBNSFP_SNP;
         SNPSIFT_DBNSFP as SNPSIFT_DBNSFP_INDEL} from "${projectDir}/modules/snpeff_snpsift/snpsift_dbnsfp"
include {GATK_HAPLOTYPECALLER;
         GATK_HAPLOTYPECALLER as GATK_HAPLOTYPECALLER_GVCF} from "${projectDir}/modules/gatk/gatk_haplotypecaller"
include {GATK_INDEXFEATUREFILE} from "${projectDir}/modules/gatk/gatk_indexfeaturefile"
include {GATK_VARIANTFILTRATION;
         GATK_VARIANTFILTRATION as GATK_VARIANTFILTRATION_SNP;
         GATK_VARIANTFILTRATION as GATK_VARIANTFILTRATION_INDEL} from "${projectDir}/modules/gatk/gatk_variantfiltration"
include {GATK_VARIANTANNOTATOR} from "${projectDir}/modules/gatk/gatk3_variantannotator"
include {GATK_MERGEVCF} from "${projectDir}/modules/gatk/gatk_mergevcf"
include {GATK_SELECTVARIANTS;
         GATK_SELECTVARIANTS as GATK_SELECTVARIANTS_SNP;
         GATK_SELECTVARIANTS as GATK_SELECTVARIANTS_INDEL} from "${projectDir}/modules/gatk/gatk_selectvariants"
include {GATK_BASERECALIBRATOR} from "${projectDir}/modules/gatk/gatk_baserecalibrator"
include {GATK_APPLYBQSR} from "${projectDir}/modules/gatk/gatk_applybqsr"

// help if needed
if (params.help){
    help()
    exit 0
}

// log params
param_log()

// prepare reads channel
if (params.csv_input) {

    ch_input_sample = extract_csv(file(params.csv_input, checkIfExists: true))

} else if (params.concat_lanes){
  
  if (params.read_type == 'PE'){
    read_ch = Channel
            .fromFilePairs("${params.sample_folder}/${params.pattern}${params.extension}",checkExists:true, flat:true )
            .map { file, file1, file2 -> tuple(getLibraryId(file), file1, file2) }
            .groupTuple()
  }
  else if (params.read_type == 'SE'){
    read_ch = Channel.fromFilePairs("${params.sample_folder}/*${params.extension}", checkExists:true, size:1 )
                .map { file, file1 -> tuple(getLibraryId(file), file1) }
                .groupTuple()
                .map{t-> [t[0], t[1].flatten()]}
  }
    // if channel is empty give error message and exit
    read_ch.ifEmpty{ exit 1, "ERROR: No Files Found in Path: ${params.sample_folder} Matching Pattern: ${params.pattern}"}

} else {
  
  if (params.read_type == 'PE'){
    read_ch = Channel.fromFilePairs("${params.sample_folder}/${params.pattern}${params.extension}",checkExists:true )
  }
  else if (params.read_type == 'SE'){
    read_ch = Channel.fromFilePairs("${params.sample_folder}/*${params.extension}",checkExists:true, size:1 )
  }
    // if channel is empty give error message and exit
    read_ch.ifEmpty{ exit 1, "ERROR: No Files Found in Path: ${params.sample_folder} Matching Pattern: ${params.pattern}"}

}

// nextflow /projects/omics_share/meta/benchmarking/ngs-ops-nf-pipelines/main.nf -profile sumner --workflow pdx_wes --gen_org human --download_data --pubdir /projects/compsci/omics_share/meta/benchmarking/pdx_test -w /projects/compsci/omics_share/meta/benchmarking/pdx_test/work --csv_input /projects/omics_share/meta/benchmarking/ngs-ops-nf-pipelines/pdx_wes_test.csv -resume


// add check and log statements to say 'Workflow was provided CSV input manifest. The settings: concat_lanes, sample_folder, pattern, extension are ignored.'

// main workflow
workflow PDX_WES {
  // Step 0: Concatenate Fastq files if required. 

  if (params.download_data){
    if (params.read_type == 'PE') {
        aria_download_input = ch_input_sample
        .multiMap { it ->
            R1: tuple(it[0], it[1], 'R1', it[2])
            R2: tuple(it[0], it[1], 'R2', it[3])
        }
        .mix()
    } else {
        aria_download_input = ch_input_sample
        .multiMap { it ->
            R1: tuple(it[0], it[1], 'R1', it[2])
        }
        .mix()
    }

    ARIA_DOWNLOAD(aria_download_input)

    concat_input = ARIA_DOWNLOAD.out.file
                        .map { it ->
                            def meta = [:]
                            meta.sample   = it[1].sample
                            meta.patient  = it[1].patient
                            meta.sex      = it[1].sample
                            meta.status   = it[1].sample
                            meta.id       = it[1].id

                            [it[0], it[1].lane, meta, it[2], it[3]]
                        }    
                        .groupTuple(by: [0,2,3])
                        .map{ it -> tuple(it[0], it[1].size(), it[2], it[3], it[4])}
                        .branch{
                            concat: it[1] > 1
                            pass:  it[1] == 1
                        }
    /* 
        remap the output to exclude lane from meta. 
        The number of lanes in the grouped lane list per sample is used to determine if concatenation is needed. 
        The branch statement determines if concat is needed or if the sample is passed to the next step. 
    */

    no_concat_samples = concat_input.pass
                        .map{it -> tuple(it[0], it[1], it[2], it[3], it[4][0])}
    /* 
        this map statement delists the single fastq samples (i.e., non-concat samples)
    */

    CONCATENATE_READS_SAMPLESHEET(concat_input.concat)

    read_meta_ch = CONCATENATE_READS_SAMPLESHEET.out.concat_fastq
    .mix(no_concat_samples)
    .groupTuple(by: [0,2])
    .map{it -> tuple(it[0], it[2], it[4].toSorted( { a, b -> a.getName() <=> b.getName() } ) ) }
    .view()

    read_meta_ch.map{it -> [it[0], it[2]]}.set{read_ch}
    read_meta_ch.map{it -> [it[0], it[1]]}.set{meta_ch}

  }

  if (params.concat_lanes && !params.csv_input){
    if (params.read_type == 'PE'){
        CONCATENATE_READS_PE(read_ch)
        read_ch = CONCATENATE_READS_PE.out.concat_fastq
    } else if (params.read_type == 'SE'){
        CONCATENATE_READS_SE(read_ch)
        read_ch = CONCATENATE_READS_SE.out.concat_fastq
    }
  }

  // // Step 1: Qual_Stat
//   QUALITY_STATISTICS(read_ch)

  // // Step 2: Get Read Group Information
  // READ_GROUPS(QUALITY_STATISTICS.out.trimmed_fastq, "gatk")

  // // Step 3: BWA-MEM Alignment
  // bwa_mem_mapping = QUALITY_STATISTICS.out.trimmed_fastq.join(READ_GROUPS.out.read_groups)
  // BWA_MEM(bwa_mem_mapping)

  // // Step 4: Variant Preprocessing - Part 1
  // PICARD_SORTSAM(BWA_MEM.out.sam)
  // PICARD_MARKDUPLICATES(PICARD_SORTSAM.out.bam)

  // // If Human: Step 5-10
  // if (params.gen_org=='human'){

  //   // Step 5: Variant Pre-Processing - Part 2
  //     GATK_BASERECALIBRATOR(PICARD_MARKDUPLICATES.out.dedup_bam)

  //     apply_bqsr = PICARD_MARKDUPLICATES.out.dedup_bam.join(GATK_BASERECALIBRATOR.out.table)
  //     GATK_APPLYBQSR(apply_bqsr)

  //   // Step 6: Variant Pre-Processing - Part 3
  //     collect_metrics = GATK_APPLYBQSR.out.bam.join(GATK_APPLYBQSR.out.bai)
  //     PICARD_COLLECTHSMETRICS(collect_metrics)

  //   // Step 7: Variant Calling
  //     haplotype_caller = GATK_APPLYBQSR.out.bam.join(GATK_APPLYBQSR.out.bai)
  //     GATK_HAPLOTYPECALLER(haplotype_caller, 'variant')

  //     haplotype_caller_gvcf = GATK_APPLYBQSR.out.bam.join(GATK_APPLYBQSR.out.bai)
  //     GATK_HAPLOTYPECALLER_GVCF(haplotype_caller_gvcf, 'gvcf')

  //   // Step 8: Variant Filtration
  //     // SNP
  //       select_var_snp = GATK_HAPLOTYPECALLER.out.vcf.join(GATK_HAPLOTYPECALLER.out.idx)
  //       GATK_SELECTVARIANTS_SNP(select_var_snp, 'SNP')

  //       var_filter_snp = GATK_SELECTVARIANTS_SNP.out.vcf.join(GATK_SELECTVARIANTS_SNP.out.idx)
  //       GATK_VARIANTFILTRATION_SNP(var_filter_snp, 'SNP')

  //     // INDEL
  //       select_var_indel = GATK_HAPLOTYPECALLER.out.vcf.join(GATK_HAPLOTYPECALLER.out.idx)
  //     	GATK_SELECTVARIANTS_INDEL(select_var_indel, 'INDEL')

  //       var_filter_indel = GATK_SELECTVARIANTS_INDEL.out.vcf.join(GATK_SELECTVARIANTS_INDEL.out.idx)
  //       GATK_VARIANTFILTRATION_INDEL(var_filter_indel, 'INDEL')

  //   // Step 9: Post Variant Calling Processing - Part 1
  //     // SNP
  //       COSMIC_ANNOTATION_SNP(GATK_VARIANTFILTRATION_SNP.out.vcf)
  //       SNPEFF_SNP(COSMIC_ANNOTATION_SNP.out.vcf, 'SNP', 'vcf')
  //       SNPSIFT_DBNSFP_SNP(SNPEFF_SNP.out.vcf, 'SNP')
  //       SNPEFF_ONEPERLINE_SNP(SNPSIFT_DBNSFP_SNP.out.vcf, 'SNP')

  //     // INDEL
  //       COSMIC_ANNOTATION_INDEL(GATK_VARIANTFILTRATION_INDEL.out.vcf)
  //       SNPEFF_INDEL(COSMIC_ANNOTATION_INDEL.out.vcf, 'INDEL', 'vcf')
  //       SNPSIFT_DBNSFP_INDEL(SNPEFF_INDEL.out.vcf, 'INDEL')
  //       SNPEFF_ONEPERLINE_INDEL(SNPSIFT_DBNSFP_INDEL.out.vcf, 'INDEL')

  //   // Step 10: Post Variant Calling Processing - Part 2
  //     vcf_files = SNPEFF_ONEPERLINE_SNP.out.vcf.join(SNPEFF_ONEPERLINE_INDEL.out.vcf)
  //     GATK_MERGEVCF(vcf_files)
      
  //     SNPSIFT_EXTRACTFIELDS(GATK_MERGEVCF.out.vcf)

  // } else if (params.gen_org=='mouse'){

  //   // Step 6: Variant Pre-Processing - Part 3
  //     collecths_metric = PICARD_MARKDUPLICATES.out.dedup_bam.join(PICARD_MARKDUPLICATES.out.dedup_bai)
  //     PICARD_COLLECTHSMETRICS(collecths_metric)
                              

  //   // Step 7: Variant Calling
  //     haplotype_caller = PICARD_MARKDUPLICATES.out.dedup_bam.join(PICARD_MARKDUPLICATES.out.dedup_bai)
  //     GATK_HAPLOTYPECALLER(haplotype_caller, 'variant')

  //   // Step 8: Variant Filtration
  //     var_filter = GATK_HAPLOTYPECALLER.out.vcf.join(GATK_HAPLOTYPECALLER.out.idx)
  //     GATK_VARIANTFILTRATION(var_filter, 'BOTH')

  //   // Step 9: Post Variant Calling Processing
  //     SNPEFF(GATK_VARIANTFILTRATION.out.vcf, 'BOTH', 'gatk')

  //     merged_vcf_files = GATK_VARIANTFILTRATION.out.vcf.join(SNPEFF.out.vcf)
  //     GATK_VARIANTANNOTATOR(merged_vcf_files)

  //     SNPSIFT_EXTRACTFIELDS(GATK_VARIANTANNOTATOR.out.vcf)

  // }

  // agg_stats = QUALITY_STATISTICS.out.quality_stats.join(PICARD_COLLECTHSMETRICS.out.hsmetrics).join(PICARD_MARKDUPLICATES.out.dedup_metrics)

  // // Step 11: Aggregate Stats
  // AGGREGATE_STATS(agg_stats)
  
}






