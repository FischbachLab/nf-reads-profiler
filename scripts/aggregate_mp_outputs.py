#!/usr/bin/env python3

import tempfile
import boto3
import botocore.exceptions
import os, sys
import pandas as pd
import numpy as np
import logging
import argparse
import concurrent.futures


def usage():
    usage = """
    python aggregate_mp_output.py \
        --s3prefix s3://gwfcore-results/Results/Reads-Profiler/2021_10_12_CP04021-A \
        --suffix metaphlan_bugs_list.tsv \
        --output 2021_10_12_CP04021-A.metaphlan_agg_rel_ab.csv
    """

    # Making default argument list structures
    p = argparse.ArgumentParser(usage=usage)
    # Required
    p.add_argument(
        "-p",
        "--s3prefix",
        dest="s3prefix",
        action="store",
        type=str,
        required=True,
        help="Common S3 Path prefix that contains all the files to be aggregated",
    )
    p.add_argument(
        "-s",
        "--suffix",
        dest="suffix",
        action="store",
        type=str,
        required=True,
        help="The unique extension/suffix of the files you wish to aggregate",
    )
    p.add_argument(
        "-o",
        "--output",
        dest="output",
        action="store",
        type=str,
        required=True,
        help="aggregated output file",
    )
    p.add_argument(
        "-c",
        "--cores",
        dest="cores",
        action="store",
        type=int,
        required=False,
        default=None,
        help="Number of processors available for this task",
    )
    p.add_argument(
        "--profile",
        dest="profile",
        action="store",
        type=str,
        required=False,
        default=None,
        help="AWS CLI profile to use, if other than the default",
    )

    return vars(p.parse_args())


# def extract_metaphlan_species_name(clade_name):
#     if "s__" not in clade_name:
#         return np.nan

#     return " ".join(clade_name.split("|")[-1].replace("s__", "").split("_"))

# def extract_metaphlan_species_taxid(clade_name, taxon_string):
#     if "s__" not in clade_name:
#         return np.nan

#     return taxon_string.split("|")[-1]


def extract_metaphlan_species_info(clade_name, ncbi_tax_id):
    # row.clade_name, row.ncbi_tax_id
    # row["clade_name"], row["ncbi_tax_id"]
    if "s__" not in clade_name:
        return np.nan, np.nan

    species = " ".join(clade_name.split("|")[-1].replace("s__", "").split("_"))
    species_tax_id = ncbi_tax_id.split("|")[-1]

    return (species, species_tax_id)


def process_metaphlan_output(sample_name, mp_out):
    """
    read metaphlan output: *_metaphlan_bugs_list.tsv
    only keep lines with species.
    remove "s__" and replace "_" b/w genus and sp name w/ space.
    s__Anaerostipes_hadrus --> Anaerostipes hadrus

    only keep first and third column.

    output is a long format 4 column table: species,species_tax_id,sample_name,relative_abundance
    """
    df = pd.read_table(
        mp_out,
        comment="#",
        header=None,
        usecols=[0, 1, 2],
        names=["clade_name", "ncbi_tax_id", "relative_abundance"],
    )

    df["sample_name"] = sample_name
    df[["species", "species_tax_id"]] = df.apply(
        lambda row: extract_metaphlan_species_info(row.clade_name, row.ncbi_tax_id),
        axis=1,
        result_type="expand",
    )

    return (
        df[["species", "species_tax_id", "sample_name", "relative_abundance"]]
        .query("species_tax_id == species_tax_id")  # remove null values
        .reset_index(drop=True)
    )


# process_metaphlan_output("BC000217_002","/Users/sunitj/Research/NuancedHealth/curated-metagenomic-data/BC000217_002_metaphlan_bugs_list.tsv",1)


def strip_s3_path(s3path):
    """
    take s3 path
    return tuple (bucket name, object key)
    """
    path_list = s3path.replace("s3://", "").split("/")
    bucket = path_list.pop(0)
    obj_key = "/".join(path_list)
    return (bucket, obj_key)


def download_file_from_s3(
    bucket_name, key_prefix, destination_prefix, aws_profile=None
):
    """
    transfer a file to/from AWS S3
    """
    if destination_prefix == ".":
        destination_prefix = os.path.curdir

    destination = os.path.join(destination_prefix, os.path.basename(key_prefix))

    # logging.info(f"Downloading {key_prefix}")
    if aws_profile is not None:
        # logging.info(f"Downloading using profile {aws_profile}")
        s3 = boto3.session.Session(profile_name=aws_profile).client("s3")
    else:
        # logging.info(f"Downloading using default profile")
        s3 = boto3.client("s3")

    try:
        s3.download_file(bucket_name, key_prefix, destination)
    except botocore.exceptions.ClientError as b:
        logging.error(
            f"Failed to retrieve object with bucket_name:{bucket_name}; key_prefix:{key_prefix}; destination:{destination}"
        )
    return destination


def get_files_list(bucket_name, key_prefix, suffix="txt", aws_profile=None):
    """Get a list of s3paths given certain restrictions on prefix and suffix
    Args:
        bucket_name (str): Name of the S3 bucket.
        prefix (str): Only fetch keys that start with this prefix (folder name).
        suffix (str, optional): Only fetch keys that end with this suffix (extension). Defaults to "txt".
    Returns:
        list: all the file names in an S3 bucket folder.
    """
    # logging.info(f"Downloading {key_prefix}")
    if aws_profile is not None:
        # logging.info(f"Downloading using profile {aws_profile}")
        s3 = boto3.session.Session(profile_name=aws_profile).client("s3")
    else:
        # logging.info(f"Downloading using default profile")
        s3 = boto3.client("s3")

    response = s3.list_objects_v2(Bucket=bucket_name, Prefix=key_prefix)
    objs = response["Contents"]

    while response["IsTruncated"]:
        response = s3.list_objects_v2(
            Bucket=bucket_name,
            Prefix=key_prefix,
            ContinuationToken=response["NextContinuationToken"],
        )
        objs.extend(response["Contents"])

    logging.info(f"Sifting through {len(objs)} files ...")

    shortlisted_files = list()
    if suffix == "":
        shortlisted_files = [obj["Key"] for obj in objs]
        total_size_bytes = sum([obj["Size"] for obj in objs])
    else:
        shortlisted_files = [obj["Key"] for obj in objs if obj["Key"].endswith(suffix)]
        total_size_bytes = sum(
            [obj["Size"] for obj in objs if obj["Key"].endswith(suffix)]
        )

    logging.info(
        f"Found {len(shortlisted_files)} files, totalling about {total_size_bytes/1e9:,.3f} Gb."
    )
    return shortlisted_files


def get_metaphlan_data(bucket_name, key_prefix, suffix, aws_profile=None):
    """
    download_file_from_s3 --> process_metaphlan_output
    """
    sample_name = os.path.basename(key_prefix).replace(suffix, "").rstrip("_")

    df = pd.DataFrame()
    with tempfile.TemporaryDirectory() as tmpdir:
        filepath = download_file_from_s3(bucket_name, key_prefix, tmpdir, aws_profile)
        df = process_metaphlan_output(sample_name, filepath)

    # num_species, _ = df.shape
    # logging.info(
    #     f"Processed file {key_prefix} for {sample_name}. Found contributions from {num_species} species"
    # )
    return df


def aggregate_mp_output(bucket, file_prefix, suffix, cores=None, aws_profile=None):
    """
    parallelize metaphlan aggregation
    1. get list of MP files (get_files_list)
    2. list of dfs = parallelize(get_metaphlan_data)
    3. return combined df from list of dfs
    """

    all_file_paths = get_files_list(bucket, file_prefix, suffix, aws_profile)

    ## Serial
    # list_of_dfs = [
    #     get_metaphlan_data(bucket, key_prefix, suffix, aws_profile)
    #     for key_prefix in all_file_paths[:10]
    # ]

    ## Parallel
    list_of_dfs = list()
    with concurrent.futures.ProcessPoolExecutor(max_workers=cores) as executor:
        future = [
            executor.submit(
                get_metaphlan_data, bucket, key_prefix, suffix, aws_profile,
            )
            for key_prefix in all_file_paths
        ]
        for f in concurrent.futures.as_completed(future):
            list_of_dfs.append(f.result())

    return pd.concat(list_of_dfs)


def main():
    args = usage()
    s3path = args["s3prefix"]
    suffix = args["suffix"]
    output = args["output"]
    use_tax_ids = args["taxid"]
    cores = args["cores"]
    aws_profile = args["profile"]

    bucket, file_obj_prefix = strip_s3_path(s3path)
    agg_mp_df = aggregate_mp_output(bucket, file_obj_prefix, suffix, cores, aws_profile)
    agg_mp_df.to_csv(output, index=False)


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s\t[%(levelname)s]:\t%(message)s",
    )

    main()
