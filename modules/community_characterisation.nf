// ------------------------------------------------------------------------------
//  COMMUNITY CHARACTERISATION
// ------------------------------------------------------------------------------
/**
	Community Characterisation - STEP 1. Performs taxonomic binning and estimates the
	microbial relative abundances using MetaPhlAn and its databases of clade-specific markers.
*/


// Defines channels for bowtie2_metaphlan_databases file
// Channel.fromPath( params.metaphlan_databases, type: 'dir', checkIfExists: true ).set { bowtie2_metaphlan_databases }

process profile_taxa {

  tag "$name"

	//Enable multicontainer settings
  container params.docker_container_metaphlan

	publishDir "${params.outdir}/${params.project}/${name}/taxa", mode: 'copy', pattern: "*.{biom,tsv,txt,bz2}"

	input:
	tuple val(name), path(reads)

	output:
	tuple val(name), path("*.biom"), emit: to_alpha_diversity
	tuple val(name), path("*_metaphlan_bugs_list.tsv"), emit: to_profile_function_bugs
	path "*_metaphlan_bugs_list.tsv", emit: to_profile_function_bugs_list
	path "profile_taxa_mqc.yaml", emit: profile_taxa_log
	path "*.bz2"

	when:
	!params.rna

	script:
	"""
	metaphlan \\
		--input_type fastq \\
		--tmp_dir . \\
		--biom ${name}.biom \\
		--index ${params.metaphlan_index} \\
		--bowtie2db ${params.metaphlan_db} \\
		--bowtie2out ${name}.bowtie2out.bz2 \\
		--bt2_ps ${params.bt2options} \\
		--add_viruses \\
		--sample_id ${name} \\
		--nproc ${task.cpus} \\
		--unclassified_estimation \\
		--offline \\
		-s ${name}.sam.bz2 \\
		$reads \\
		${name}_metaphlan_bugs_list.tsv 1> profile_taxa_mqc.txt

	# MultiQC doesn't have a module for Metaphlan yet. As a consequence, I
	# had to create a YAML pathwith all the info I need via a bash script
	bash scrape_profile_taxa_log.sh ${name}_metaphlan_bugs_list.tsv > profile_taxa_mqc.yaml
	"""
}


/**
	Community Characterisation - STEP 2. Performs the functional annotation using HUMAnN.
*/

// Defines channels for bowtie2_metaphlan_databases file
// Channel.fromPath( params.chocophlan, type: 'dir', checkIfExists: true ).set { chocophlan_databases }
// Channel.fromPath( params.uniref, type: 'dir', checkIfExists: true ).set { uniref_databases }

process profile_function {

    tag "$name"

	//Enable multicontainer settings
  container params.docker_container_biobakery

	publishDir {params.rna ? "${params.outdir}/${params.project}/${name}/function/metaT" : "${params.outdir}/${params.project}/${name}/function/metaG" }, mode: 'copy', pattern: "*.{tsv,log}"

	input:
	tuple val(name), path(reads)
	tuple val(name), path(metaphlan_bug_list)

  output:
	path "*_HUMAnN.log"
	path "*_genefamilies.tsv"
	path "*_pathcoverage.tsv"
	path "*_pathabundance.tsv"
	path "profile_functions_mqc.yaml", emit: profile_function_log

	when:
	params.annotation

	script:
	"""
	head -n 3 ${metaphlan_bug_list}
	ls -lhtr ${metaphlan_bug_list}
	#HUMAnN will use the list of species detected by the profile_taxa process
	humann \\
		--input $reads \\
		--output . \\
		--output-basename ${name} \\
		--taxonomic-profile ${metaphlan_bug_list} \\
		--nucleotide-database ${params.chocophlan} \\
		--protein-database ${params.uniref} \\
		--pathways metacyc \\
		--threads ${task.cpus} \\
		--memory-use minimum &> ${name}_HUMAnN.log

	# MultiQC doesn't have a module for humann yet. As a consequence, I
	# had to create a YAML file with all the info I need via a bash script
	bash scrape_profile_functions.sh ${name} ${name}_HUMAnN.log > profile_functions_mqc.yaml
 	"""
}


/**
	Community Characterisation - STEP 3. Evaluates several alpha-diversity measures.

*/

process alpha_diversity {

  tag "$name"

	container params.docker_container_qiime2

	publishDir "${params.outdir}/${params.project}/${name}/alpha_diversity", mode: 'copy', pattern: "*.{tsv}"

	input:
	tuple val(name), path(metaphlan_bug_list)

  output:
	path "*_alpha_diversity.tsv", emit: alpha_diversity_tsv
	path "alpha_diversity_mqc.yaml", emit: alpha_diversity_log

	when:
	!params.rna

	script:
	"""
	#It checks if the profiling was successful, that is if identifies at least three species
	n=\$(grep -o s__ $metaphlan_bug_list | wc -l  | cut -d\" \" -f 1)
	if (( n <= 3 )); then
		#The file should be created in order to be returned
		touch ${name}_alpha_diversity.tsv
	else
		echo $name > ${name}_alpha_diversity.tsv
		qiime tools import --input-path $metaphlan_bug_list --type 'FeatureTable[Frequency]' --input-format BIOMV100Format --output-path ${name}_abundance_table.qza
		for alpha in ace berger_parker_d brillouin_d chao1 chao1_ci dominance doubles enspie esty_ci fisher_alpha gini_index goods_coverage heip_e kempton_taylor_q lladser_pe margalef mcintosh_d mcintosh_e menhinick michaelis_menten_fit osd pielou_e robbins shannon simpson simpson_e singles strong
		do
			qiime diversity alpha --i-table ${name}_abundance_table.qza --p-metric \$alpha --output-dir \$alpha &> /dev/null
			qiime tools export --input-path \$alpha/alpha_diversity.qza --output-path \${alpha} &> /dev/null
			value=\$(sed -n '2p' \${alpha}/alpha-diversity.tsv | cut -f 2)
		    echo -e  \$alpha'\t'\$value
		done >> ${name}_alpha_diversity.tsv
	fi

	# MultiQC doesn't have a module for qiime yet. As a consequence, I
	# had to create a YAML file with all the info I need via a bash script
	bash generate_alpha_diversity_log.sh \${n} > alpha_diversity_mqc.yaml
	"""
}

/*
 merge the bug list tables by samples
 generate the species only heatmap if there are enough species to display
*/
process merge_mp_results {

	tag params.project

	errorStrategy = 'ignore'

    container params.docker_container_biobakery 
    publishDir "${params.outdir}/${params.project}/merged_metaphlan_results/"

    input:
      path "metaphlan_bugs_list/*"

    output:
	  path "merged_metaphlan_abundance_species.tsv", emit: samples
	  path "full_taxonomy_merged_metaphlan_abundance_species.tsv"
	  path "merged_metaphlan_species_prevalence.tsv"

  script:
  """
    ls -lhtr metaphlan_bugs_list
	merge_bug_list.sh metaphlan_bugs_list

	calculate_prevalence.R merged_metaphlan_abundance_species.tsv

  """
}


process sample_mp_results {

	tag params.project

	errorStrategy = 'ignore'

    container params.docker_container_datamash 
    publishDir "${params.outdir}/${params.project}/merged_metaphlan_results/"

    input:
      path "merged_metaphlan_abundance_species.tsv"

    output:
	  path "merged_metaphlan_abundance_samples.tsv"

  script:
  """
	datamash transpose -H < merged_metaphlan_abundance_species.tsv > merged_metaphlan_abundance_samples.tsv
	sed -i '1s/^/sample_name/' merged_metaphlan_abundance_samples.tsv

  """
}

