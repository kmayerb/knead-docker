# knead-docker

[![Build Status](https://travis-ci.com/kmayerb/knead-docker.svg?branch=master)](https://travis-ci.com/kmayerb/knead-docker)

### Modifying Existing Dockerfiles

### KNEADDATA

A slight modification was needed to the Docker image provided at DokcerHub biobakery/kneaddata:0.7.2 from the Huttenhower Lab. Nexflow requires some basic tools when running on AWS Batch, namely ps, that were not included on the base image.

A Dockerfile in this repo includes the one-line modification to add ps. The docker image is built and hosted using quay.io.
{[Dockerfile](https://github.com/kmayerb/knead-docker/blob/master/Dockerfile)} and {[quay.io](https://quay.io/repository/kmayerb/docker-knead?tab=tags)}

```
quay.io/kmayerb/docker-knead@sha256:392c79e403f06d0ee8b884ad63d6654484a8935726a8ff524fa29f03d991cfdb
```

### FASTQC 

mitochondria {[Dockerfile](https://github.com/kmayerb/mitochondria/commit/31d03c3586434f5545cba106b0efcc8885b5f2c4)} and {[quay.io](https://quay.io/repository/kmayerb/mitochondria?tab=tags)}

```
quay.io/kmayerb/mitochondria:0.0.1
quay.io/kmayerb/mitochondria@sha256:54cd567a2eccc82a7134dfdbfde57e7d8dfe205a0ba8f62312ced8ff517f43bf 
```
tag: 0.0.1

### MULTIQC

A Dockerfile existed but wasn't tagged to the latest stable release. I forked the official MultiQC repo, created a v1.8nf branch, rewound that branch to the commit associated with the stable 1.8 release. And built a docker container from that checkpoint. The only modification to the Docker container was to remove the entrypoint.

Multiqc {[Dockerfile](https://github.com/kmayerb/MultiQC/blob/v1.8nf/Dockerfile)} and {[quay.io](https://quay.io/repository/kmayerb/nf-multiqc?tab=tags)}
```
quay.io/kmayerb/nf-multiqc:v1.8nf
quay.io/kmayerb/nf-multiqc@sha256:964402c37bc87b1ddba1e757c6675a6df7c8009c85660c8d654688699eed5f10
```
tag: v.1.8nf

### Running Nextflow 

Start with a Nextflow workflow hosted in a GitHub repo (in this case kmayerb/docker-knead/)

The file main.nf is the default workflow that is run in the process described below. The file main-test.nf is 
a toy version for trying things on Travis-CI.


### Create a batchfile.csv

Next, create a .csv specifying the inputs to the workflow. 

```
name,fastq1,fastq2
C73PMACXX_7_AGGCAGAA_CTAAGCCT,s3://fh-pi-lastname-f/../C73PMACXX_7_AGGCAGAA_CTAAGCCT.R1.fq.fastq.gz, s3://fh-pi-lastname-f/../C73PMACXX_7_AGGCAGAA_CTAAGCCT.R2.fq.fastq.gz
```


### Create the run.sh bash script

Next, create a bash script (run.sh). This defines some variables and makes the actual call to Nextflow.  At Fred Hutch, this will be run from within the Rhinos (notice ml nextflow loads the appropriate module). Save run.sh in a project file associated with the project.

```bash
#! bin/bash
ml nextflow

# Reference database
BATCHFILE=trial_econ_nextflow_cf_batch.csv
OUTPUT_FOLDER=s3://fh-pi-kublin-j-microbiome/CF/trim_trial/2019_12_30_trim_trial/
PROJECT=trim_test
WORK_DIR=s3://fh-pi-kublin-j-microbiome/scratch-delete30/nextflow/

NXF_VER=19.10.0 nextflow \
    -c nextflow-aws-econ.config \
    run \
    kmayerb/knead-docker \
        -r 0.1.8\
        --batchfile $BATCHFILE \
        --output_folder $OUTPUT_FOLDER \
        --output_prefix $PROJECT \
        -with-report $PROJECT.html \
        -work-dir $WORK_DIR \
        -with-tower \
	-resume
```

### Create your nextflow-aws.config
This must be configured locally to specifiy user-specific credentials

```bash
AWSROLE=
AWSIAM=
TOWERTOKEN=
```

```bash
process.executor = 'awsbatch'
// // Run the analysis on the specified queue in AWS Batch

process.queue = 'spot-test'
// // Run in the correct AWS region


// // Mount the host folder /docker_scratch to /tmp within the running job
// // Use /tmp for scratch space to provide a larger working directory
// // Replace with the Job Role ARN for your account
aws {
    region = 'us-west-2'
    batch {
        cliPath = '/home/ec2-user/miniconda/bin/aws'
        jobRole = 'arn:aws:iam::${AWSIAM}:role/${AWSROLE}'
        volumes = ['/docker_scratch:/tmp:rw']
    }
}

tower {
  accessToken = '${TOWERTOKEN}'
  enabled = true
}

docker {
    enabled = true
    temp = 'auto'
}

process {
    withName: 'knead' {
        cpus = 1
        memory = 8.GB
    }
    withName: 'compress' {
        cpus = 1
        memory = 4.GB
    }
    withName: 'fastqc_on_raw_files' {
        cpus = 1
        memory = 4.GB
    }
    withName: 'fastqc_on_trimmed_files' {
        cpus = 1
        memory = 4.GB
    }
    withName: 'multiqc' {
        cpus = 1
        memory = 4.GB
    }
}

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
And, for a second example, **params.output_folder** is passed to the publishDir setting within a process to specify where to dump the outputs

```nextflow
publishDir params.output_folder
```

1. BATCHFILE - the file specifying samples into the workflow
2. OUTPUT_FOLDER - specified in your workflow as params.output_folder which is passed to publishDir within a process.
This will likely be an S3 Bucket + prefix. 
3. PROJECT - the name of you project. Not used here except for naming hte report file
4. WORK_DIR - the place where all of nextflows termporary work files are stored. This baloons. So should probably be dumped within a set amount of time to minimize the bucket's ecological footprint.


### Quick Testing in a container

The fastest way to troubleshoot is to work in a container. (Mounting a volume can provide access to input files)
```
docker run -v ${HOME}/active-testing/knead-docker/examples/:/root -it quay.io/kmayerb/docker-knead@sha256:392c79e403f06d0ee8b884ad63d6654484a8935726a8ff524fa29f03d991cfdb
mkdir reference
mkdir results
tar -zxf root/demo.tar.gz -C reference --strip-components 1
```
