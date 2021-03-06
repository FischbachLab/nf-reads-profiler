## Acknowledgement

This pipeline is based on the original [YAMP](https://github.com/alesssia/YAMP) repo. Modifications have been made to make use of our infrastrucutre more readily. If you're here for a more customizable and flexible pipeline, please consider taking a look at the original repo.

# nf-reads-profiler

## Usage

```{bash}
aws batch submit-job \
    --profile maf \
    --job-name nf-rp-1210-1 \
    --job-queue priority-maf-pipelines \
    --job-definition nextflow-production \
    --container-overrides command=s3://nextflow-pipelines/nf-reads-profiler,\
"--prefix","paired_end_test",\
"--singleEnd","false",\
"--reads1","s3://czb-seqbot/fastqs/200817_NB501938_0185_AH23FNBGXG/MITI_Purification_Healthy/E8_SH0000236_0619-Cult-2-481_S22_R1_001.fastq.gz",\
"--reads2","s3://czb-seqbot/fastqs/200817_NB501938_0185_AH23FNBGXG/MITI_Purification_Healthy/E8_SH0000236_0619-Cult-2-481_S22_R2_001.fastq.gz"
```

### Same account test

"--reads1","s3://dev-scratch/fastq/small/random_ncbi_reads_with_duplicated_and_contaminants_R1.fastq.gz",\
"--reads2","s3://dev-scratch/fastq/small/random_ncbi_reads_with_duplicated_and_contaminants_R2.fastq.gz"

### Cross account test

"--reads1","s3://czb-seqbot/fastqs/200817_NB501938_0185_AH23FNBGXG/MITI_Purification_Healthy/E8_SH0000236_0619-Cult-2-481_S22_R1_001.fastq.gz",\
"--reads2","s3://czb-seqbot/fastqs/200817_NB501938_0185_AH23FNBGXG/MITI_Purification_Healthy/E8_SH0000236_0619-Cult-2-481_S22_R2_001.fastq.gz"

## Databases

Although the databases have been stored at the appropriate `/mnt/efs/databases` location mentioned in the config file. There might come a time when these need to be updated. Here is a quick view on how to do that.

### Metaphlan3

```{bash}
cd /mnt/efs/databases/Biobakery
docker container run \
    --volume $PWD:$PWD \
    --workdir $PWD \
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
    --rm \
    biobakery/workflows:3.0.0.a.7 \
        humann_databases \
        --download \
        uniref uniref90_diamond .
```

This will create a subdirectory `uniref`, and download and extract the database here.

## Updating the pipeline

```{bash}
cd nf-reads-profiler
aws s3 sync --profile maf . s3://nextflow-pipelines/nf-reads-profiler --delete --exclude '.git*' --exclude '*.gz'
```
