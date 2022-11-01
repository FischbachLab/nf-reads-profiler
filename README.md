## Acknowledgement

This pipeline is based on the original [YAMP](https://github.com/alesssia/YAMP) repo. Modifications have been made to make use of our infrastrucutre more readily. If you're here for a more customizable and flexible pipeline, please consider taking a look at the original repo.

# nf-reads-profiler

## Usage

```{bash}
aws batch submit-job \
    --profile maf \
    --job-name nf-rp-1101-2 \
    --job-queue priority-maf-pipelines \
    --job-definition nextflow-production \
    --container-overrides command=fischbachlab/nf-reads-profiler,\
"--prefix","branch_metaphlan4",\
"--singleEnd","false",\
"--reads1","s3://dev-scratch/fastq/small/random_ncbi_reads_with_duplicated_and_contaminants_R1.fastq.gz",\
"--reads2","s3://dev-scratch/fastq/small/random_ncbi_reads_with_duplicated_and_contaminants_R2.fastq.gz"
```

### Cross account test

```bash
"--reads1","s3://czb-seqbot/fastqs/200817_NB501938_0185_AH23FNBGXG/MITI_Purification_Healthy/E8_SH0000236_0619-Cult-2-481_S22_R1_001.fastq.gz",\
"--reads2","s3://czb-seqbot/fastqs/200817_NB501938_0185_AH23FNBGXG/MITI_Purification_Healthy/E8_SH0000236_0619-Cult-2-481_S22_R2_001.fastq.gz"
```

## Databases

Although the databases have been stored at the appropriate `/mnt/efs/databases` location mentioned in the config file. There might come a time when these need to be updated. Here is a quick view on how to do that.

### Metaphlan4

```{bash}
cd /mnt/efs/databases/Biobakery/Metaphlan/v4.0
docker container run \
    --volume $PWD:$PWD \
    --workdir $PWD \
    --rm \
    458432034220.dkr.ecr.us-west-2.amazonaws.com/biobakery/workflows:maf-20221028-a1 \
    metaphlan \
        --install \
        --nproc 4 \
        --bowtie2db .
```

### Humann3

This requires 3 databases.

#### Chocophlan

```{bash}
cd /mnt/efs/databases/Biobakery/Humann/v3.6
docker container run \
    --volume $PWD:$PWD \
    --workdir $PWD \
    --rm \
    458432034220.dkr.ecr.us-west-2.amazonaws.com/biobakery/workflows:maf-20221028-a1 \
        humann_databases \
        --download \
            chocophlan full .
```

This will create a subdirectory `chocophlan`, and download and extract the database here.

#### Uniref

```{bash}
cd /mnt/efs/databases/Biobakery/Humann/v3.6
docker container run \
    --volume $PWD:$PWD \
    --workdir $PWD \
    --rm \
    458432034220.dkr.ecr.us-west-2.amazonaws.com/biobakery/workflows:maf-20221028-a1 \
        humann_databases \
        --download \
        uniref uniref90_diamond .
```

This will create a subdirectory `uniref`, and download and extract the database here.

#### Utility Script Databases

```bash
cd /mnt/efs/databases/Biobakery/Humann/v3.6
docker container run \
    --volume $PWD:$PWD \
    --workdir $PWD \
    --rm \
    458432034220.dkr.ecr.us-west-2.amazonaws.com/biobakery/workflows:maf-20221028-a1 \
    humann_databases \
        --download \
        utility_mapping full .
```
