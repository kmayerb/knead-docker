// The purpose of the is workflow is to quality trim and remove human contaminant reads from shutgun microbome samples

// example paired inputs

//C73PMACXX_4_GCTACGCT_AGAGTAGA
//s3://fh-pi-kublin-j-microbiome/read_only/CF/C73PMACXX_4_GCTACGCT_AGAGTAGA.R1.fq.fastq.gz
//s3://fh-pi-kublin-j-microbiome/read_only/CF/C73PMACXX_4_GCTACGCT_AGAGTAGA.R2.fq.fastq.gz

// outputs that we want to store - quality trimmed and filtered reads
//C73PMACXX_4_GCTACGCT_AGAGTAGA.R1.fq_kneaddata.trimmed.2.fastq
//C73PMACXX_4_GCTACGCT_AGAGTAGA.R1.fq_kneaddata.trimmed.1.fastq

// outputs that we want to store - quality trimmed and human contaminant filtered reads
//C73PMACXX_4_GCTACGCT_AGAGTAGA.R1.fq_kneaddata_paired_1.fastq
//C73PMACXX_4_GCTACGCT_AGAGTAGA.R1.fq_kneaddata_paired_2.fastq

// location of the human decoy bowtie files to be unzipped and untared 

params.human_decoy = "s3://fh-pi-kublin-j-microbiome/read_only/REF/Homo_sapiens_hg37_and_human_contamination_Bowtie2_v0.1.tar.gz"

// destination folder for all trimmed reads

params.output_folder  = "s3://fh-pi-kublin-j-microbiome/read_only/CFTRIMTEST/"


Channel.from(file(params.batchfile))
          .splitCsv(header: true, sep: ",")
          .map { sample ->
          [sample.name, file(sample.fastq1), file(sample.fastq2)]}
          .set{ kneaddata_ch }


// deal with .gz file a docker file
process knead {
	container "quay.io/kmayerb/docker-knead@sha256:392c79e403f06d0ee8b884ad63d6654484a8935726a8ff524fa29f03d991cfdb"
	cpus 2
	memory "8 GB"
	
	publishDir "${params.output_folder}"

	input:
	set sample_name, file(fastq1), file(fastq2) from kneaddata_ch
	file refdb_targz from file(params.human_decoy)

	output:
	set sample_name, file("${sample_name}.R1.fq_kneaddata_paired_1.fastq.tar.gz"), file("${sample_name}.R1.fq_kneaddata_paired_2.fastq.tar.gz") into next_ch

	afterScript "rm *"

	"""
	mkdir reference
	mkdir results
	tar -zxf ${refdb_targz} -C reference --strip-components 1
	kneaddata --input ${fastq1} --input ${fastq2} -db reference/ --output results
	tar -czvf ${sample_name}.R1.fq_kneaddata_paired_1.fastq.tar.gz --directory=./results/ ${sample_name}.R1.fq_kneaddata_paired_1.fastq
	tar -czvf ${sample_name}.R1.fq_kneaddata_paired_2.fastq.tar.gz --directory=./results/ ${sample_name}.R1.fq_kneaddata_paired_2.fastq
	"""       
}





