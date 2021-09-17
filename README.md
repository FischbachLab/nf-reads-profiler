## Acknowledgement

YAMP pipeline

# nf-reads-profiler

## Usage

```{bash}
aws batch submit-job \
    --profile maf \
    --job-name nf-rp-0914-2 \
    --job-queue default-maf-pipelines \
    --job-definition nextflow-production \
    --container-overrides command=s3://nextflow-pipelines/nf-reads-profiler,\
"--prefix","paired_end_test",\
"--singleEnd","false",\
"--reads1","s3://nextflow-pipelines/nf-reads-profiler/data/test_data/random_ncbi_reads_with_duplicated_and_contaminants_R1.fastq.gz",\
"--reads2","s3://nextflow-pipelines/nf-reads-profiler/data/test_data/random_ncbi_reads_with_duplicated_and_contaminants_R2.fastq.gz"
```

## Databases

Although the databases have been stored at the appropriate `/mnt/efs/databases` location mentioned in the config file. There might come a time when these need to be updated. Here is a quick view on how to do that.

### Metaphlan3

```{bash}
cd /mnt/efs/databases/Biobakery
docker container run \
    --volume $PWD:$PWD \
    --workdir $PWD \
    -it \
    --rm \
    biobakery/workflows:3.0.0.a.7 \
    metaphlan \
        --install \
        --bowtie2db metaphlan
```

### Humann3

This requires 2 databases.

#### Chocophlan

```{bash}
cd /mnt/efs/databases/Biobakery
docker container run \
    --volume $PWD:$PWD \
    --workdir $PWD \
    -it \
    --rm \
    biobakery/workflows:3.0.0.a.7 \
        humann_databases \
        --download \
            chocophlan full .
```

This will create a subdirectory `chocophlan`, and download and extract the database here.

#### Uniref

```{bash}
cd /mnt/efs/databases/Biobakery
docker container run \
    --volume $PWD:$PWD \
    --workdir $PWD \
    -it \
    --rm \
    biobakery/workflows:3.0.0.a.7 \
        humann_databases \
        --download \
        uniref uniref90_diamond .
```

This will create a subdirectory `uniref`, and download and extract the database here.
