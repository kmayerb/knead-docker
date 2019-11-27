FROM biobakery/kneaddata:0.7.2

MAINTAINER kmayerblackwell kmayerbl@fredhutch.org

/*
 * Minimal modifications biobakery/kneaddata:0.7.2 image
 * 
 *this is for documentation purpose only.
 *
 * IS TO BIG TO BUILD INTO THE IMAGE?
 * It is recommended that you download the human (hg37_and_human_contamination) 
 * reference database (approx. size = 3.5 GB). However, this step is not required if you are using your own custom
 * reference database or if you will not be nning with a reference databas e.
 * This database is based on the Decoy Genome (http://www.cureffi.org/2013/02/01/the-decoy-genome/) 
 * and contaminants taken from “Human contamination in bacterial genomes has created thousands of spurious proteins”
 * (Salzberg et. al. 2019 )
 */

apt-get update && apt-get install -y procps








