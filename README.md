# knead-docker

[![Build Status](https://travis-ci.com/kmayerb/knead-docker.svg?branch=master)](https://travis-ci.com/kmayerb/knead-docker)

### Modifying your Dockerfile

A slight modification was needed to the Docker image provided at DokcerHub biobakery/kneaddata:0.7.2 from the the Huttenhower Lab. 

Nexflow requires some basic tools, namely ps, that were not included on the base image.

A Dockerfile in this repor includes the one-line modification. The docker image is built and hosted using quay.io (https://quay.io/repository/kmayerb/docker-knead)


```
quay.io/kmayerb/docker-knead@sha256:392c79e403f06d0ee8b884ad63d6654484a8935726a8ff524fa29f03d991cfdb
```

### Running Nextflow 

Start with a nextflow workflow mainted in a github repo (in this case kmayerb/docker-knead/)

The file main.nf is the default workflow that is run in the process described below. The file main-test.nf is 
a toy version for trying things on travis-CI.


### Create a batchfile.csv

Next create a batchfile CSV specifying inputs to the workflow. 

```
name,fastq1,fastq2
C73PMACXX_7_AGGCAGAA_CTAAGCCT,s3://fh-pi-lastname-f/../C73PMACXX_7_AGGCAGAA_CTAAGCCT.R1.fq.fastq.gz, s3://fh-pi-lastname-f/../C73PMACXX_7_AGGCAGAA_CTAAGCCT.R2.fq.fastq.gz
```


Next you create a run script (run.sh). This defines some variables and makes the call to nextflow.  This will be run from 
within the rhinos cluster and can be saved in a project folder associated with the project.

### Create a run.sh
```bash
#! bin/bash
ml nextflow

# Reference database
BATCHFILE=trial_nextflow_cf_batch.csv
OUTPUT_FOLDER=s3://fh-pi-kublin-j-microbiome/read_only/CFTRIMTEST/
PROJECT=trimtest
WORK_DIR=s3://fh-pi-kublin-j-microbiome/scratch-delete30/nextflow/

NXF_VER=19.10.0 nextflow \
    -c ~/nextflow-aws.config \
    run \
    kmayerb/knead-docker \
        -r 0.0.1 \
        --batchfile $BATCHFILE \
        --output_folder $OUTPUT_FOLDER \
        --output_prefix $PROJECT \
        -with-report $PROJECT.html \
        -work-dir $WORK_DIR \
        -with-tower \
        -resume
```

The run.sh is a means of passing parameters to the nf-script. --flag will be passed to params.flag in the main.nf script.

For instance **params.batchfiles** appears in the script in instantiation of the first Channel:

```nextflow
Channel.from(file(params.batchfile))
          .splitCsv(header: true, sep: ",")
          .map { sample ->
          [sample.name, file(sample.fastq1), file(sample.fastq2)]}
          .set{ kneaddata_ch }
```
and, for a secodn example, **params.output_folder** is passed to the publishDir setting within a process to specify where to dump the outputs

```nextflow
publishDir "${params.output_folder}"
```

1. BATCHFILE - the file specifying samples into the workflow
2. OUTPUT_FOLDER - specified in your workflow as params.output_folder which is passed to publishDir within a process.
This will likely be an S3 Bucket + prefix. 
3. PROJECT - the name of you project. Not used here except for naming hte report file
4. WORK_DIR - the place where all of nextflows termporary work files are stored. This baloons. So should probably be dumped within a set amount of time to minimize the bucket's ecological footprint.


### Quick Testing in a container

probably the fastest way to troubleshoot is to work in a container. (mounting a volume can provide access to input fils)
```
docker run -v ${HOME}/active-testing/knead-docker/examples/:/root -it quay.io/kmayerb/docker-knead@sha256:392c79e403f06d0ee8b884ad63d6654484a8935726a8ff524fa29f03d991cfdb
mkdir reference
mkdir results
tar -zxf root/demo.tar.gz -C reference --strip-components 1
kneaddata --input ref
```