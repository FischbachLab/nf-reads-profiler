#!/usr/bin/env nextflow


def versionMessage() 
{
	log.info"""
	 
	YET ANOTHER METAGENOMIC PIPELINE (nf-reads-profiler) - Version: ${workflow.manifest.version} 
	""".stripIndent()
}

def helpMessage() 
{
	log.info"""

Metaphlan 3 (nf-reads-profiler) - Version: ${workflow.manifest.version} 
  
  Mandatory arguments:
    --reads1   R1      Forward (if paired-end) OR all reads (if single-end) file path
    [--reads2] R2      Reverse reads file path (only if paired-end library layout)
    --prefix   prefix  Prefix used to name the result files
    --outdir   path    Output directory (will be outdir/prefix/)
  
  Main options:
    --singleEnd  <true|false>   whether the layout is single-end
  
  Other options:
  MetaPhlAn parameters for taxa profiling:
    --metaphlan_db path    folder for the MetaPhlAn database
    --bt2options          value   BowTie2 options
  
  HUMANn parameters for functional profiling:
    --chocophlan          path    folder for the ChocoPhlAn database
    --uniref              path	  folder for the UniRef database

nf-profile-reads supports FASTQ and compressed FASTQ files.
"""
}

/**
Prints version when asked for
*/
if (params.version) {
	versionMessage()
	exit 0
}

/**
Prints help when asked for
*/

if (params.help) {
	helpMessage()
	exit 0
}

//--reads2 can be omitted when the library layout is "single" (indeed it specifies single-end
//sequencing)
if (!params.singleEnd && (params.reads2 == "null") ) {
	exit 1, "If dealing with paired-end reads, please set the reads2 parameters\nif dealing with single-end reads, please set the library layout to 'single'"
}

//--reads1 and --reads2 can be omitted (and the default from the config file used instead) 
//only when mode is "characterisation". Obviously, --reads2 should be always omitted when the
//library layout is single.
if ((!params.singleEnd && (params.reads1 == "null" || params.reads2 == "null")) || (params.singleEnd && params.reads1 == "null")) {
	exit 1, "Please set the reads1 and/or reads2 parameters"
}

//Creates working dir
workingpath = params.outdir + "/" + params.prefix
workingdir = file(workingpath)
if( !workingdir.exists() ) {
	if( !workingdir.mkdirs() ) 	{
		exit 1, "Cannot create working directory: $workingpath"
	} 
}	


// Header log info
log.info """---------------------------------------------
Metaphlan (nf-profile-reads) 
---------------------------------------------

Analysis introspection:

"""

def summary = [:]

summary['Starting time'] = new java.util.Date() 
//Environment
summary['Environment'] = ""
summary['Pipeline Name'] = 'nf-profile-reads'
summary['Pipeline Version'] = workflow.manifest.version

summary['Config Profile'] = workflow.profile
summary['Resumed'] = workflow.resume
		
summary['Nextflow version'] = nextflow.version.toString() + " build " + nextflow.build.toString() + " (" + nextflow.timestamp + ")"

summary['Java version'] = System.getProperty("java.version")
summary['Java Virtual Machine'] = System.getProperty("java.vm.name") + "(" + System.getProperty("java.vm.version") + ")"

summary['Operating system'] = System.getProperty("os.name") + " " + System.getProperty("os.arch") + " v" +  System.getProperty("os.version")
summary['User name'] = System.getProperty("user.name") //User's account name

summary['Container Engine'] = workflow.containerEngine
if(workflow.containerEngine) summary['Container'] = workflow.container
summary['biobakery'] = params.docker_container_biobakery
summary['MultiQC'] = params.docker_container_multiqc

//General
summary['Running parameters'] = ""
summary['Reads'] = "[" + params.reads1 + ", " + params.reads2 + "]"
summary['Prefix'] = params.prefix
summary['Layout'] = params.singleEnd ? 'Single-End' : 'Paired-End'
summary['Merge Reads'] = params.mergeReads

//BowTie2 databases for metaphlan
summary['MetaPhlAn parameters'] = ""
summary['MetaPhlAn database'] = params.metaphlan_databases
summary['Bowtie2 options'] = params.bt2options

// ChocoPhlAn and UniRef databases
summary['HUMAnN parameters'] = ""
summary['Chocophlan database'] = params.chocophlan
summary['Uniref database'] = params.uniref

//Folders
summary['Folders'] = ""
summary['Output dir'] = workingpath
summary['Working dir'] = workflow.workDir
summary['Output dir'] = params.outdir
summary['Script dir'] = workflow.projectDir
summary['Lunching dir'] = workflow.launchDir

log.info summary.collect { k,v -> "${k.padRight(27)}: $v" }.join("\n")
log.info ""


/**
	Prepare workflow introspection

	This process adds the workflow introspection (also printed at runtime) in the logs
	This is NF-CORE code.
*/

def create_workflow_summary(summary) {
    def yaml_file = workDir.resolve('workflow_summary_mqc.yaml')
    yaml_file.text  = """
    id: 'workflow-summary'
    description: "This information is collected when the pipeline is started."
    section_name: 'nf-profile-reads Workflow Summary'
    section_href: 'https://github.com/fischbachlab/nf-profile-reads'
    plot_type: 'html'
    data: |
        <dl class=\"dl-horizontal\">
${summary.collect { k,v -> "            <dt>$k</dt><dd>$v</dd>" }.join("\n")}
        </dl>
    """.stripIndent()

   return yaml_file
}

/**
	Gets software version. 

	This process ensures that software version are included in the logs.
*/

process get_software_versions {

	//Starting the biobakery container. I need to run metaphlan and Humann to get
	//their version number (due to the fact that they live in the same container)
    container params.docker_container_biobakery

	output:
	file "software_versions_mqc.yaml" into software_versions_yaml

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
		
	echo $params.docker_container_multiqc | cut -d: -f 2 > v_multiqc.txt
	
	scrape_software_versions.py > software_versions_mqc.yaml
	"""
}

// ------------------------------------------------------------------------------   
//  COMMUNITY CHARACTERISATION 
// ------------------------------------------------------------------------------   

// The user will specify the clean file either as a single clean file (that is the nf-profile-reads
// default behaviour), or as two files (forward/reverse). ]
// In the former case, the user will set singleEnd = true and only one file will be 
// selected and used directly for taxa and community profiling.
// In the latter case, the user will set singleEnd = false and provide two files, that will
// be merged before feeding the relevant channels for profiling.
if (params.singleEnd) {
	Channel
	.from([[params.prefix, [file(params.reads1)]]])
	.into { to_profile_taxa; to_profile_functions }
	
	//Initialise empty channels
	reads_merge_paired_end_cleaned = Channel.empty()
	merge_paired_end_cleaned_log = Channel.empty()
} else if (!params.singleEnd) {
	Channel
	.from([[params.prefix, [file(params.reads1), file(params.reads2)]]] )
	.set { reads_merge_paired_end_cleaned }
	
	//Stage boilerplate log
	merge_paired_end_cleaned_log = Channel.from(file("$baseDir/assets/merge_paired_end_cleaned_mqc.yaml"))
	
	//Initialise empty channels
	to_profile_taxa = Channel.empty()
	to_profile_functions = Channel.empty()
} 

process merge_paired_end_cleaned {

	tag "$name"
		
	input:
	tuple val(name), file(reads) from reads_merge_paired_end_cleaned
	
	output:
	tuple val(name), path("*_QCd.fq.gz") into to_profile_taxa_merged
	tuple val(name), path("*_QCd.fq.gz") into to_profile_functions_merged
	
	when:
	!params.singleEnd

   	script:
	"""
	# This step will have no logging because the information are not relevant
	# I will simply use a boilerplate YAML to record that this has happened
	# If the files were not compressed, they will be at this stage
	if (file ${reads[0]} | grep -q compressed ) ; then
	    cat ${reads[0]} ${reads[1]} > ${name}_QCd.fq.gz
	else
		cat ${reads[0]} ${reads[1]} | gzip > ${name}_QCd.fq.gz
	fi
	"""
}

/**
	Community Characterisation - STEP 1. Performs taxonomic binning and estimates the 
	microbial relative abundances using MetaPhlAn and its databases of clade-specific markers.
*/


// Defines channels for bowtie2_metaphlan_databases file 
// Channel.fromPath( params.metaphlan_databases, type: 'dir', checkIfExists: true ).set { bowtie2_metaphlan_databases }

process profile_taxa {

    tag "$name"

	//Enable multicontainer settings
    container params.docker_container_biobakery

	publishDir "${params.outdir}/${params.prefix}", mode: 'copy', pattern: "*.{biom,tsv}"
	
	input:
	tuple val(name), file(reads) from to_profile_taxa.mix(to_profile_taxa_merged)
	
	output:
	tuple val(name), path("*.biom") into to_alpha_diversity
	tuple val(name), path("*_metaphlan_bugs_list.tsv") into to_profile_function_bugs
	file "profile_taxa_mqc.yaml" into profile_taxa_log
	
	
	script:
	"""
	metaphlan \\
		--input_type fastq \\
		--tmp_dir=. \\
		--biom ${name}.biom \\
		--bowtie2out=${name}_bt2out.txt \\
		--bowtie2db ${params.metaphlan_db} \\
		--bt2_ps ${params.bt2options} \\
		--add_viruses \\
		--sample_id ${name} \\
		--nproc ${task.cpus} \\
		$reads \\
		${name}_metaphlan_bugs_list.tsv &> profile_taxa_mqc.txt
	
	# MultiQC doesn't have a module for Metaphlan yet. As a consequence, I
	# had to create a YAML file with all the info I need via a bash script
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

	publishDir "${params.outdir}/${params.prefix}", mode: 'copy', pattern: "*.{tsv,log}"
	
	input:
	tuple val(name), file(reads) from to_profile_functions.mix(to_profile_functions_merged)
	tuple val(name), file(metaphlan_bug_list) from to_profile_function_bugs
	
    output:
	file "*_HUMAnN.log"
	file "*_genefamilies.tsv"
	file "*_pathcoverage.tsv"
	file "*_pathabundance.tsv"
	file "profile_functions_mqc.yaml" into profile_functions_log

	script:
	"""
	#HUMAnN will use the list of species detected by the profile_taxa process
	humann \\
		--input $reads \\
		--output . \\
		--output-basename ${name} \\
		--taxonomic-profile $metaphlan_bug_list \\
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

	publishDir "${params.outdir}/${params.prefix}", mode: 'copy', pattern: "*.{tsv}"
	
	input:
	tuple val(name), file(metaphlan_bug_list) from to_alpha_diversity
		
    output:
	file "*_alpha_diversity.tsv"
	file "alpha_diversity_mqc.yaml" into alpha_diversity_log

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


// ------------------------------------------------------------------------------   
//	MULTIQC LOGGING
// ------------------------------------------------------------------------------   


/**
	Generate Logs. 

	Logs generate at each analysis step are collected and processed with MultiQC 
*/

// Stage config files
multiqc_config = file(params.multiqc_config)

process log {
	
	publishDir "${params.outdir}/${params.prefix}", mode: 'copy'

    container params.docker_container_multiqc

	input:
	file multiqc_config
	file workflow_summary from create_workflow_summary(summary)
	file "software_versions_mqc.yaml" from software_versions_yaml
	file "merge_paired_end_cleaned_mqc.yaml" from merge_paired_end_cleaned_log.ifEmpty([])
	file "profile_taxa_mqc.yaml" from profile_taxa_log.ifEmpty([])
	file "profile_functions_mqc.yaml" from profile_functions_log.ifEmpty([])
	file "alpha_diversity_mqc.yaml" from alpha_diversity_log.ifEmpty([])
	
	output:
	path "*multiqc_report*.html" into multiqc_report
	path "*multiqc_data*"

	script:
	"""
	multiqc --config $multiqc_config . -f
	mv multiqc_report.html ${params.prefix}_multiqc_report.html
	mv multiqc_data ${params.prefix}_multiqc_data
	"""
}


