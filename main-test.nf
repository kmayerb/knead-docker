// Travis-CI test

params.tar = "demo.tar.gz"
params.output_folder = "./"
params.batchfile = "batchfile-testonly.csv"

Channel.from(file(params.batchfile))
          .splitCsv(header: true, sep: ",")
          .map { sample ->
          [sample.name, file(sample.fastq1), file(sample.fastq2)]}
          .set{ kneaddata_ch }

process knead {
	container "quay.io/kmayerb/docker-knead@sha256:392c79e403f06d0ee8b884ad63d6654484a8935726a8ff524fa29f03d991cfdb"

	publishDir "${params.output_folder}"

	input:
	set sample_name, file(fastq1), file(fastq2) from kneaddata_ch
	file refdb_targz from file(params.tar)

	output:
	set file("results/${sample_name}_kneaddata.fastq") into next_ch
	
	afterScript "rm *"

	"""
	echo ${fastq1}
	mkdir reference
	mkdir results
	tar -zxf ${refdb_targz} -C reference --strip-components 1
	kneaddata --input ${fastq1} --reference-db reference/demo_db --output results
	"""       
}
