
/**
	Gets software version.

	This process ensures that software version are included in the logs.
*/

process get_software_versions {

	//Starting the biobakery container. I need to run metaphlan and Humann to get
	//their version number (due to the fact that they live in the same container)
  container params.docker_container_biobakery

  publishDir "${params.outdir}/${params.project}/pipeline_info", mode: 'copy'

	//input:
	//val (some_value)

	output:
	path "software_versions_mqc.yaml", emit: software_versions_yaml

	script:
	//I am using a multi-containers scenarios, supporting docker and singularity
	//with the software at a specific version (the same for all platforms). Therefore, I
	//will simply parse the version from there. Perhaps overkill, but who cares?
	//This is not true for the biobakery suite (metaphlan/humann) which extract the
	//information at runtime from the actual commands (see comment above)
	"""
	echo $workflow.manifest.version > v_pipeline.txt
	echo $workflow.nextflow.version > v_nextflow.txt

	metaphlan --version > v_metaphlan.txt
	humann --version > v_humann.txt

	echo $params.docker_container_qiime2 | cut -d: -f 2 > v_qiime.txt
	echo $params.docker_container_multiqc | cut -d: -f 2 > v_multiqc.txt

	scrape_software_versions.py > software_versions_mqc.yaml
	"""
}
/*
Get the database versions from metaphlan and humann 
*/
process get_database_versions {

	//Starting the biobakery container. I need to run metaphlan and Humann to get
	//their version number (due to the fact that they live in the same container)
  container params.docker_container_biobakery

  publishDir "${params.outdir}/${params.project}/pipeline_info", mode: 'copy'

	//input:
	//val (some_value)

	output:
	path "database_versions.txt"

	script:
	
	"""
	echo "MetaPhlAn database:" > database_versions.txt
	echo $params.metaphlan_index >> database_versions.txt
	echo "MetaPhlAn database path:" >> database_versions.txt
	echo $params.metaphlan_db >> database_versions.txt
	echo " " >> database_versions.txt
	echo "HUMAnN database path:" >> database_versions.txt
	echo $params.chocophlan >> database_versions.txt
	echo $params.uniref >> database_versions.txt
	"""
}


process merge_paired_end_cleaned {

	tag "$name"
	container params.docker_container_bbmap

	input:
	tuple val(name), path(reads)

	output:
	tuple val(name), path("*_QCd.fq.gz"), emit: to_profile_taxa_merged
	tuple val(name), path("*_QCd.fq.gz"), emit: to_profile_functions_merged

	when:
	!params.singleEnd

   	script:
	"""
	# This step will have no logging because the information are not relevant
	# I will simply use a boilerplate YAML to record that this has happened
	# If the files were not compressed, they will be at this stage

	#Sets the maximum memory to the value requested in the config file
    maxmem=\$(echo \"$task.memory\" | sed 's/ //g' | sed 's/B//g')

	reformat.sh -Xmx\"\$maxmem\" in1=${reads[0]} in2=${reads[1]} out=${name}_QCd.fq.gz threads=${task.cpus}
	"""
}

// ------------------------------------------------------------------------------
//	MULTIQC LOGGING
// ------------------------------------------------------------------------------


/**
	Generate Logs.

	Logs generate at each analysis step are collected and processed with MultiQC
*/




process log {

	publishDir "${params.outdir}/${params.project}/pipeline_info", mode: 'copy'

  container params.docker_container_multiqc

	input:
	file multiqc_config
	//path workflow_summary
	file "software_versions_mqc.yaml"
	file "merge_paired_end_cleaned_mqc.yaml"
	file "profile_taxa_mqc.yaml"
	file "profile_functions_mqc.yaml"
	file "alpha_diversity_mqc.yaml"

	output:
	path "${params.prefix}_multiqc_report.html"
	path "${params.prefix}_multiqc_data"

	script:
	"""
	multiqc --config $multiqc_config . -f
	mv multiqc_report.html ${params.prefix}_multiqc_report.html
	mv multiqc_data ${params.prefix}_multiqc_data
	"""
}
