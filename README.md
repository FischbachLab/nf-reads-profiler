## Acknowledgement

This pipeline is based on the original [YAMP](https://github.com/alesssia/YAMP) repo. Modifications have been made to make use of our infrastrucutre more readily. If you're here for a more customizable and flexible pipeline, please consider taking a look at the original repo.

# nf-reads-profiler

## Usage

### Example1: preferred usage (--seedfile)
```{bash}
aws batch submit-job \
   --job-name nf-readprofiler_20240709_DS-mNGS \
   --job-queue priority-maf-pipelines  \
   --job-definition nextflow-production \
   --container-overrides command="s3://nextflow-pipelines/nf-reads-profiler, \ 
"--project","20240709_DS-mNGS", \
"--singleEnd","false",  \
"--seedfile","s3://genomics-workflow-core/Results/reads-profiler/seedfiles/20240709_DS-mNGS.seedfile.csv" \
"--outdir","s3://genomics-workflow-core/Results/reads-profiler" "
```

### A seedfile example for paired-end samples

- The `seedfile` should be a __THREE__ column csv file with the following headers.

```{bash}
sampleName,R1,R2
20240614_DS037_D01_R1.fastq.gz,s3://genomics-workflow-core/Results/Basespace/NextSeq/20240709_DS-mNGS_HKT5LBGXW/20240614_DS037_D01_R1.fastq.gz_R1_001.fastq.gz,s3://genomics-workflow-core/Results/Basespace/NextSeq/20240709_DS-mNGS_HKT5LBGXW/20240614_DS037_D01_R1.fastq.gz_R2_001.fastq.gz
20240614_DS038_E01_R1.fastq.gz,s3://genomics-workflow-core/Results/Basespace/NextSeq/20240709_DS-mNGS_HKT5LBGXW/20240614_DS038_E01_R1.fastq.gz_R1_001.fastq.gz,s3://genomics-workflow-core/Results/Basespace/NextSeq/20240709_DS-mNGS_HKT5LBGXW/20240614_DS038_E01_R1.fastq.gz_R2_001.fastq.gz
```

### Example2: --reads1 and --reads2 flags for paired end sample
```{bash}
aws batch submit-job \
    --profile maf \
    --job-name nf-rp-1101-2 \
    --job-queue priority-maf-pipelines \
    --job-definition nextflow-production \
    --container-overrides command=fischbachlab/nf-reads-profiler,\
"--project","TEST",\
"--prefix","branch_metaphlan4",\
"--singleEnd","false",\
"--reads1","s3://dev-scratch/fastq/small/random_ncbi_reads_with_duplicated_and_contaminants_R1.fastq.gz",\
"--reads2","s3://dev-scratch/fastq/small/random_ncbi_reads_with_duplicated_and_contaminants_R2.fastq.gz"
```

### Outputs

- The final output is a single tab-delimited table from a set of sample-specific abundance profiles (the sample names, feature taxonomies, and relative abundances) in the folder, e.g., s3://genomics-workflow-core/Results/reads-profiler/20240709_DS-mNGS/merged_metaphlan_results/

```{bash}
	20240614_LKV_AK12_DC_240604_C05	20240614_LKV_AK22_DC_240604_C06
UNCLASSIFIED	1.38723	5.63586
Bacteroides_fragilis	74.71778448588894	0.0
Odoribacter_splanchnicus	7.2665189180272725	2.12202312969113
Bacteroides_xylanisolvens	3.4467235358389776	0.09979951893316047
Bacteroides_thetaiotaomicron	1.8451929194769707	0.0
Ligilactobacillus_salivarius	1.4416497259818657	0.0
Alistipes_onderdonkii	1.38628851469499	0.0
Prevotella_bivia	1.2946871089871548	0.0
Alistipes_communis	1.2718188067117246	5.0323360110009645
```

<!-- -->
- Optionally, a taxon-by-sample heatmap is created in the folder merged_metaphlan_results/ too if there are enough species detected across samples.
![An example heatmap](assets/images/example-heatmap.png =200x300)

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
