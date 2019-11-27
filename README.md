# knead-docker

### Running Nextflow 

This example is based on using a github repo as the resting place of your workflow. The file main.nf is the default workflow


### Create a batchfile

This file specifies the sample name and associated paired end files that are input
```
name,fastq1,fastq2
C73PMACXX_7_AGGCAGAA_CTAAGCCT,s3://fh-pi-kublin-j-microbiome/read_only/CF/C73PMACXX_7_AGGCAGAA_CTAAGCCT.R2.fq.fastq.gz,s3://fh-pi-kublin-j-microbiome/read_only/CF/C73PMACXX_7_AGGCAGAA_CTAAGCCT.R1.fq.fastq.gz
```

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
    kmayerbl/knead-docker \
        -r 0.0.1 \
        --batchfile $BATCHFILE \
        --output_folder $OUTPUT_FOLDER \
        --output_prefix $PROJECT \
        -with-report $PROJECT.html \
        -work-dir $WORK_DIR \
        -with-tower \
        -resume
```

