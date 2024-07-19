#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include { profile_taxa; profile_function; alpha_diversity; merge_mp_results} from './modules/community_characterisation'
include { merge_paired_end_cleaned; get_software_versions; log } from './modules/house_keeping'

def versionMessage()
{
	log.info"""

	nf-reads-profiler - Version: ${workflow.manifest.version}
	""".stripIndent()
}

def helpMessage()
{
	log.info"""

nf-reads-profiler - Version: ${workflow.manifest.version}

  Mandatory arguments:
    --reads1   R1      Forward (if paired-end) OR all reads (if single-end) path path
    [--reads2] R2      Reverse reads file path (only if paired-end library layout)
	--seedfile file    A file contains sample name, reads1 and reads2
    --prefix   prefix  Prefix used to name the result files
    --outdir   path    Output directory (will be outdir/prefix/)

  Main options:
    --singleEnd  <true|false>   whether the layout is single-end

  Other options:
  MetaPhlAn parameters for taxa profiling:
    --metaphlan_db path   folder for the MetaPhlAn database
    --bt2options          value   BowTie2 options

  HUMANn parameters for functional profiling:
    --taxonomic_profile	  path	  s3path to precalculate metaphlan3 taxonomic profile output.
    --chocophlan          path    folder for the ChocoPhlAn database
    --uniref              path	  folder for the UniRef database
	--annotation  <true|false>   whether annotation is enabled (default: false)

nf-reads-profiler supports FASTQ and compressed FASTQ files.
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
// either a seedfile or a read file path
if ((!params.seedfile == "null") && (!params.reads1 == "null") ) {
	exit 1, "please use either the seedfile or reads1 path option, not both"
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

// if rna is True, taxonomic profile is required.
// if (params.rna && params.taxonomic_profile == ""){
// 	exit 1, "Please set the --taxonomic_profile parameter for transcriptiomic data."
// }

//Creates working dir
workingpath = params.outdir + "/" + params.project
workingdir = file(workingpath)
if( !workingdir.exists() ) {
	if( !workingdir.mkdirs() ) 	{
		exit 1, "Cannot create working directory: $workingpath"
	}
}


// Header log info
log.info """---------------------------------------------
nf-reads-profiler
---------------------------------------------

Analysis introspection:

"""

def summary = [:]

summary['Starting time'] = new java.util.Date()
//Environment
summary['Environment'] = ""
summary['Pipeline Name'] = 'nf-reads-profiler'
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
summary['Data Type'] = params.rna ? 'Metatranscriptomic' : 'Metagenomic'
summary['Merge Reads'] = params.mergeReads

//BowTie2 databases for metaphlan
summary['MetaPhlAn parameters'] = ""
summary['MetaPhlAn database'] = params.metaphlan_db
summary['Bowtie2 options'] = params.bt2options

// ChocoPhlAn and UniRef databases
summary['HUMAnN parameters'] = ""
summary['Taxonomic Profile'] = params.taxonomic_profile
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
    def yaml_file = workDir.resolve("${params.prefix}.workflow_summary_mqc.yaml")
    yaml_file.text  = """
    id: 'workflow-summary'
    description: "This information is collected when the pipeline is started."
    section_name: 'nf-reads-profiler Workflow Summary'
    section_href: 'https://github.com/fischbachlab/nf-reads-profiler'
    plot_type: 'html'
    data: |
        <dl class=\"dl-horizontal\">
${summary.collect { k,v -> "            <dt>$k</dt><dd>$v</dd>" }.join("\n")}
        </dl>
    """.stripIndent()

   return yaml_file
}




// The user will specify the clean path either as a single clean file (that is the nf-reads-profiler
// default behaviour), or as two files (forward/reverse). ]
// In the former case, the user will set singleEnd = true and only one file will be
// selected and used directly for taxa and community profiling.
// In the latter case, the user will set singleEnd = false and provide two files, that will
// be merged before feeding the relevant channels for profiling.
if (params.singleEnd) {

		seedfile_ch = Channel
			.fromPath(params.seedfile)
			.ifEmpty { exit 1, "Cannot find any seed file matching: ${params.seedfile}" }
			.splitCsv(header: ['prefix', 'reads1'], sep: ',', skip: 1)
			.map{ row -> tuple([row.prefix, [row.reads1]])}

		to_profile_taxa_functions = seedfile_ch
		//Channel
		//	.fromList([[params.prefix, [params.reads1]]])

		//Initialise empty channels
		reads_merge_paired_end_cleaned = Channel.empty()
		merge_paired_end_cleaned_log = Channel.empty()
	} else if (!params.singleEnd) {

		 seedfile_ch = Channel
			.fromPath(params.seedfile)
			.ifEmpty { exit 1, "Cannot find any seed file matching: ${params.seedfile}" }
			.splitCsv(header: ['prefix', 'reads1', 'reads2'], sep: ',', skip: 1)
			.map{ row -> tuple([row.prefix, [row.reads1, row.reads2]]) }

		reads_merge_paired_end_cleaned = seedfile_ch 
		//Channel
		//	.fromList([[params.prefix, [params.reads1, params.reads2]]] )

		//Stage boilerplate log
		merge_paired_end_cleaned_log = Channel.fromPath("$projectDir/assets/merge_paired_end_cleaned_mqc.yaml")

		//Initialise empty channels
		to_profile_taxa_functions = Channel.empty()
}


if (params.rna){
	custom_taxa_profile = Channel
			.fromPath(params.seedfile)
			.ifEmpty { exit 1, "Cannot find any seed file matching: ${params.seedfile}" }
			.splitCsv(header: ['prefix', 'reads1', 'reads2'], sep: ',', skip: 1)
			.map{ row -> tuple([row.prefix, params.taxonomic_profile])}

//		.fromList([[params.prefix, params.taxonomic_profile]])
}
else{
	custom_taxa_profile = Channel.empty()
}



workflow {

	//Channel.of(1) |
	get_software_versions()

	//workflow_summary = create_workflow_summary(summary)

	reads_merge_paired_end_cleaned | merge_paired_end_cleaned

	to_profile_taxa_functions.mix(merge_paired_end_cleaned.out.to_profile_taxa_merged) | profile_taxa

	profile_function_ch1 = to_profile_taxa_functions.mix(merge_paired_end_cleaned.out.to_profile_functions_merged)

	profile_function_ch2 = profile_taxa.out.to_profile_function_bugs.mix(custom_taxa_profile)

	profile_function(profile_function_ch1, profile_function_ch2)

	alpha_diversity(profile_taxa.out.to_alpha_diversity)

	merge_mp_results( profile_taxa.out.to_profile_function_bugs_list.toSortedList())

}

/*
*/

// Stage config files
/*
multiqc_config = file(params.multiqc_config)

log( multiqc_config,
		//workflow_summary,
		get_software_versions.out.software_versions_yaml,
		merge_paired_end_cleaned_log.ifEmpty([]),
		profile_taxa.out.profile_taxa_log.ifEmpty([]),
		profile_function.out.profile_function_log.ifEmpty([]),
		alpha_diversity.out.alpha_diversity_log.ifEmpty([])
	)
*/
