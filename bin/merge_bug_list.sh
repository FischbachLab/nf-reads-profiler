#!/bin/bash

#set -e
#set -u
set -o pipefail

folder=${1}

merge_metaphlan_tables.py ${folder}/* > merged_abundance_table.tsv

grep -E "s__|metaphlan|UNCLASSIFIED" merged_abundance_table.tsv | grep -v "t__" | sed "s/^.*|//g" | sed "s/_metaphlan_bugs_list//g" | sed "s/s__//g"  > merged_metaphlan_abundance_species.tsv
    