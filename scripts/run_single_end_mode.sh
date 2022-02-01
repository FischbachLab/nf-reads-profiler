#!/bin/bash -x

set -euo pipefail

PROJECT=${1}
PREFIX=${2}
FASTQ=${3}

aws batch submit-job \
    --job-name "nf-rp-${PREFIX}" \
    --job-queue priority-maf-pipelines \
    --job-definition nextflow-production \
    --container-overrides command=s3://nextflow-pipelines/nf-reads-profiler,\
"--project","${PROJECT}",\
"--prefix","${PREFIX}",\
"--singleEnd","true",\
"--reads1","${FASTQ}"