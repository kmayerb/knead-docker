// Travis-CI test

// [channel] designates as channel
// {process} designates a process


// PROCESSES:
	// {knead}
	// {compress}
	// {fastqc_on_raw_files}
	// {fastqc_on_trimmed_files}
	// {multiqc}

// CHANNELS:
	// [kneaddata_channel]
	// [post_knead_channel]
	// [post_knead_channel_copy]
	// [postknead_fastqc_R1]
	// [postknead_fastqc_R2]
	// [raw_reads_to_fastqc_channel]
	// [raw_fastqc_R1]
	// [raw_fastqc_R2]
	

// THE OVERALL WORKFLOW:
// 1. FASTQC the raw reads
// [raw_reads_to_fastqc_channel] -> 
	// {fastqc_on_raw_files} -> 
		// [raw_fastqc_R1] AND [raw_fastqc_R2] ->  
			// {multiqc}

// 2. KNEAD, FASTQC
// [kneaddata_channel] -> 
	// {knead} -> 
		// [post_knead_channel] ->  {fastqc_on_trimmed_files} -> 
				// [postknead_fastqc_R1] AND [postknead_fastqc_R2] -> 
					// {multiqc}
	    // [post_knead_channel_copy] ->  {compress}

// 3. MULTIQC mixes and collects items in channelsfrom fastqc pre and post knead
	// [raw_fastqc_R1] AND [raw_fastqc_R2] AND [postknead_fastqc_R1] AND [postknead_fastqc_R2] -> {multiqc}

// demo.tar.gz contains bowtie2 database for testing read-decontamination
params.tar = "demo.tar.gz"
// location to send outputs
params.output_folder = "./pubs"
// batchfile
params.batchfile = "batchfile-testonly.csv"

Channel.from(file(params.batchfile))
          .splitCsv(header: true, sep: ",")
          .map { sample ->
          [sample.name, file(sample.fastq1), file(sample.fastq2)]}
          .set{ kneaddata_channel }

Channel.from(file(params.batchfile))
          .splitCsv(header: true, sep: ",")
          .map { sample ->
          [sample.name, file(sample.fastq1), file(sample.fastq2)]}
          .set{ raw_reads_to_fastqc_channel}


process knead {
	
	// kneaddata (more info: https://bitbucket.org/biobakery/kneaddata/wiki/Home)

	// input:
	// name, name.R1.fq, name.R2.fq

	// output:
	// name, name.R1.kneaddata_paired.fq, name.R2.kneaddata_paired.fq

	tag "kneaddata [trimmomatic + bowtie2 human read decon]"

	container "quay.io/kmayerb/docker-knead@sha256:392c79e403f06d0ee8b884ad63d6654484a8935726a8ff524fa29f03d991cfdb"
	
	publishDir params.output_folder

	input:
	set sample_name, file(fastq1), file(fastq2) from kneaddata_channel
	file refdb_targz from file(params.tar)

	output:
	set sample_name,\
	file("results/${fastq1.getBaseName()}.kneaddata_paired.fq"),\
	file("results/${fastq2.getBaseName()}.kneaddata_paired.fq") into post_knead_channel

	set sample_name,\
	file("results/${fastq1.getBaseName()}.kneaddata_paired.fq"),\
	file("results/${fastq2.getBaseName()}.kneaddata_paired.fq") into post_knead_channel_copy
	
	file("results/peak.txt") into nowhere
	
	afterScript "rm *"

	// reference folder holds reference for read trim + decon
	// results folder hold results of kneaddata
	// untar/unzip the contents of refdb_targz bowtie database to reference folder
	// run kneaddata
	// kneaddata PE produces two files name.R1._kneadata_paired_1.fastq, name.R1._kneadata_paired_2.fastq
	// RENAME: name.R1._kneadata_paired_1.fastq -> name.R1.kneadata_paired.fastq
	// RENAME: name.R2._kneadata_paired_2.fastq -> name.R2.kneadata_paired.fastq
	script:
	"""
	mkdir reference
	mkdir results
	tar -zxf ${refdb_targz} -C reference --strip-components 1
	kneaddata --input ${fastq1} --input ${fastq2} --reference-db reference/demo_db --output results
	ls -la results | more > results/peak.txt
	mv results/${fastq1.getBaseName()}_kneaddata_paired_1.fastq results/${fastq1.getBaseName()}.kneaddata_paired.fq
	mv results/${fastq1.getBaseName()}_kneaddata_paired_2.fastq results/${fastq2.getBaseName()}.kneaddata_paired.fq
	"""       
}


process compress {
	// tar and zip the kneaded files

	container "ubuntu:20.04"

	publishDir params.output_folder

	input:
	set sample_name, file(fastq1_kneaded), file(fastq2_kneaded) from post_knead_channel_copy

	output:
	set sample_name, file("results/${fastq1_kneaded.getBaseName()}.tar.gz"), file("results/${fastq2_kneaded.getBaseName()}.tar.gz") into compressed_channel

	afterScript "rm *"

	script:
	"""
	mkdir results
	tar -czvf results/${fastq1_kneaded.getBaseName()}.tar.gz ${fastq1_kneaded}
	tar -czvf results/${fastq2_kneaded.getBaseName()}.tar.gz ${fastq2_kneaded}
	"""
}

process fastqc_on_raw_files {
	tag "FASTQC ON RAW INPUT .fq FILES"

	container 'quay.io/kmayerb/mitochondria@sha256:d48892f367b217116874ca18e5f5fa602413d6a6030bccd02228f2a4153a3067'

	publishDir params.output_folder

	input:
	set sample_name, file(fastq1), file(fastq2) from raw_reads_to_fastqc_channel

	output:
    file("outputs/${fastq1.getBaseName()}_fastqc.{zip,html}") into raw_fastqc_R1
    file("outputs/${fastq2.getBaseName()}_fastqc.{zip,html}") into raw_fastqc_R2

	script:
	"""
	mkdir outputs
	fastqc -t $task.cpus -o outputs -f fastq -q ${fastq1}
	fastqc -t $task.cpus -o outputs -f fastq -q ${fastq2}
	"""
}

process fastqc_on_trimmed_files {

	tag "FASTQC ON POST KNEADDATA .fq FILES"

	container 'quay.io/kmayerb/mitochondria@sha256:d48892f367b217116874ca18e5f5fa602413d6a6030bccd02228f2a4153a3067'

	publishDir params.output_folder

	input:
	set sample_name, file(fastq1), file(fastq2) from post_knead_channel

	output:
    file("outputs2/${fastq1.getBaseName()}_fastqc.{zip,html}") into postknead_fastqc_R1
    file("outputs2/${fastq2.getBaseName()}_fastqc.{zip,html}") into postknead_fastqc_R2

	script:
	"""
	mkdir outputs2
	fastqc -t $task.cpus -o outputs2 -f fastq -q ${fastq1}
	fastqc -t $task.cpus -o outputs2 -f fastq -q ${fastq2}
	"""
}

process multiqc {

	container "quay.io/kmayerb/nf-multiqc:v1.8nf"

	publishDir params.output_folder

	tag "Pre-Trimming MULTIQC report generation"

	input:
    file('fastqc/*') from raw_fastqc_R1.mix(raw_fastqc_R2).mix(postknead_fastqc_R1).mix(postknead_fastqc_R2).collect()

    output:
    file('pre_multiqc_report_raw.html')

    script:
    """
    multiqc . -o ./ -n pre_multiqc_report_raw.html -m fastqc
    """

}







