#!/bin/bash

#set -e
#set -u
set -o pipefail

folder=${1}

merge_metaphlan_tables.py ${folder}/* > merged_abundance_table.tsv

# output results with species level only
grep -E "s__|metaphlan|UNCLASSIFIED" merged_abundance_table.tsv | grep -v "t__" | sed "s/^.*|//g" | sed "s/_metaphlan_bugs_list//g" | sed "s/s__//g"  > merged_metaphlan_abundance_species.tsv

# output results with full rank taxonomy 
grep -E "s__|metaphlan|UNCLASSIFIED" merged_abundance_table.tsv | grep -v "t__" | sed "s/_metaphlan_bugs_list//g" |  sed "s/k__//g" |  sed "s/p__//g" | sed "s/c__//g" |  sed "s/o__//g" |  sed "s/f__//g" |  sed "s/g__//g" | sed "s/s__//g" | sed "s/|/,/g" > full_taxonomy_merged_metaphlan_abundance_species.tsv

# output results by sample names
datamash transpose -H < merged_metaphlan_abundance_species.tsv > merged_metaphlan_abundance_samples.tsv

sed -i '1s/^/sample_name/' merged_metaphlan_abundance_samples.tsv