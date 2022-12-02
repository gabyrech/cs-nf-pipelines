process BEDTOOLS_GERMLINE_FILTER {
    // This modules is a port of the NYGC germline filtering scheme found at this site:
    // https://bitbucket.nygenome.org/projects/WDL/repos/somatic_dna_wdl/browse/germline/germline.wdl?at=7.4.0

    tag "$sampleID"

    cpus = 1
    memory = 2.GB
    time = '00:30:00'

    container 'broadinstitute/gatk:4.2.4.1'

    publishDir "${params.pubdir}/${ params.organize_by=='sample' ? sampleID : 'bedtools' }", pattern: "*.haplotypecaller.gatk.final.filtered.vcf.gz", mode:'copy'

    input:
    tuple val(sampleID), file(vcf)
    tuple val(sampleID), file(vcf_index)

    output:
    tuple val(sampleID), file("*haplotypecaller.gatk.final.filtered.vcf.gz"), emit: vcf
    tuple val(sampleID), file("*haplotypecaller.gatk.final.filtered.vcf.gz.idx"), emit: idx

    script:
    """
    ## Remove existing AF annotations from merged VCF
    bcftools annotate \
    -x INFO/AF \
    -Oz \
    ${vcf} \
    > noaf.vcf.gz
    
    tabix -p vcf noaf.vcf.gz

    ## Annotate with NYGC AF for filtering
    bcftools annotate \
    --annotations ${params.nygcAf} \
    --columns 'INFO/AF,INFO/AC_Hom' \
    -Oz \
    noaf.vcf.gz \
    > ${sampleID}.final.annotated.vcf.gz

    tabix -p vcf ${sampleID}.final.annotated.vcf.gz

    ## filter variants >3% AF and >10 Homozygotes in NYGC vars
    bcftools filter \
    --exclude 'INFO/AF[*] > 0.03 || INFO/AC_Hom[*] > 10' \
    ${sampleID}.final.annotated.vcf.gz \
    > ${sampleID}.pop.filtered.vcf

    bgzip ${sampleID}.pop.filtered.vcf
    tabix -p vcf ${sampleID}.pop.filtered.vcf.gz

    ## select whitelist variants
    bcftools view \
    -Oz \
    -R ${params.whitelist} \
    ${vcf} \
    > ${sampleID}.whitelist.filtered.vcf.gz

    tabix -p vcf ${sampleID}.whitelist.filtered.vcf.gz

    ## select pgx variants
    bcftools view \
    -Oz \
    -R ${params.pgx} \
    ${vcf} \ 
    > ${sampleID}.pgx.filtered.vcf.gz

    tabix -p vcf ${sampleID}.pgx.filtered.vcf.gz

    ## select chd whitelist variants
    bcftools view \
    -Oz \
    -R ${params.chdWhitelistVcf} \
    ${vcf} \
    > ${sampleID}.chdwhitelist.filtered.vcf.gz

    tabix -p vcf ${sampleID}.chdwhitelist.filtered.vcf.gz

    ## select rwgs pgx variants
    bcftools view \
    -Oz \
    -R ${params.rwgsPgxBed} \
    ${vcf} \
    > ${sampleID}.rwgspgx.filtered.vcf.gz

    tabix -p vcf ${sampleID}.rwgspgx.filtered.vcf.gz

    ## Select deep intronics
    bcftools view \
    -Oz \
    -R ${params.deepIntronicsVcf} \
    ${vcf} \
    > ${sampleID}.deep_intronics.filtered.vcf.gz

    tabix -p vcf ${sampleID}.deep_intronics.filtered.vcf.gz

    ## Select clinvar intronics
    bcftools view \
    -Oz \
    -R ${params.clinvarIntronicsVcf} \
    ${vcf} \
    > ${sampleID}.clinvar_intronics.filtered.vcf.gz

    tabix -p vcf ${sampleID}.clinvar_intronics.filtered.vcf.gz

    echo ${sampleId} > samples.txt

    ## merge all filtered files for further processing
    bcftools concat \
    -a \
    -d all \
    ${sampleID}.pop.filtered.vcf.gz \
    ${sampleID}.whitelist.filtered.vcf.gz \
    ${sampleID}.pgx.filtered.vcf.gz \
    ${sampleID}.chdwhitelist.filtered.vcf.gz \
    ${sampleID}.rwgspgx.filtered.vcf.gz \
    ${sampleID}.deep_intronics.filtered.vcf.gz \
    ${sampleID}.clinvar_intronics.filtered.vcf.gz \
    | \
    bcftools view \
    -i 'GT[@samples.txt]="alt"' \
    | \
    bcftools sort \
    -Oz \
    > ${sampleID}_haplotypecaller.gatk.final.filtered.vcf.gz

    tabix -p vcf ${sampleID}_haplotypecaller.gatk.final.filtered.vcf.gz

    """
}