#!/usr/bin/env Rscript

library(tidyverse)

args <- commandArgs(trailingOnly = TRUE)
input_path  <- args[1]

df = read_tsv(input_path, col_names = TRUE)

#Uses the gsub() function to replace blanks with an underscore in species col
#df$species <-  gsub(" ", "_", df$species)

#remove target SGB number
#df <- filter (df, !grepl("^t.+SGB*", species))   # !="^t.+SGB*")

#print(df)
#gather all columns except the first one
df <- gather(df, key="sample_name", value="relative_abundance", -species_name) %>%
      filter( relative_abundance > 0)

prevalence_df <-group_by(df, species_name) %>%
  summarize( prevalence = n(),
             mean_abundance = mean(relative_abundance),
             median_abundance = median(relative_abundance)
           ) 

write_tsv(prevalence_df , "merged_metaphlan_species_prevalence.tsv")