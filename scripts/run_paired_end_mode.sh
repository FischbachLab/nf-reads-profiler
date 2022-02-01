#!/bin/bash -x

set -euo pipefail

PROJECT=${1}
PREFIX=${2}
FWD=${3}
REV=${4}

aws batch submit-job \
    --job-name "nf-rp-${PREFIX}" \
    --job-queue priority-maf-pipelines \
    --job-definition nextflow-production \
    --container-overrides command=s3://nextflow-pipelines/nf-reads-profiler,\
"--project","${PROJECT}",\
"--prefix","${PREFIX}",\
"--singleEnd","false",\
"--reads1","${FWD}",\
"--reads2","${REV}"