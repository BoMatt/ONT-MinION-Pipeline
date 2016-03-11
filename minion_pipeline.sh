#!/bin/bash

###This pipeline requires the installation of poreQC, Poreminion, poretools and NanoOK

###Define variables and folders
minion_folder="name_of_main_directory" #Folder containing all the MinION's projects/sequencing runs
project_name="project_directory" #Project/Sequencing Run folder
sample_name="sample" #prefix for poreQC output files
reference_name="sequence" #necessary to create an index of the reference sequence used for the alignment
reference_fasta="sequence.fasta" #name of the reference sequence file used for the alignment
poreqc_directory="path_to_poreqc_script" #path to the poreqc directory

###Create working directories
echo 'Creating working directories...'
mkdir ${minion_folder}/${project_name}
mkdir ${minion_folder}/${project_name}/fast5
mkdir ${minion_folder}/${project_name}/fast5/fail
mkdir ${minion_folder}/${project_name}/fast5/pass
mkdir ${minion_folder}/${project_name}/poretools_temp
mkdir ${minion_folder}/${project_name}/stats
mkdir ${minion_folder}/${project_name}/plots
mkdir ${minion_folder}/${project_name}/poreqc_analysis
mkdir ${minion_folder}/${project_name}/reads
mkdir ${minion_folder}/${project_name}/reads/downloads
mkdir ${minion_folder}/${project_name}/reads/downloads/pass
mkdir ${minion_folder}/${project_name}/reads/downloads/fail
mkdir ${minion_folder}/reference_nanook/${reference_name}

###Copy reference file in the folder used by Poreminion
echo 'Copying references and creating symbolic links for Poreminion...'
cp ${minion_folder}/reference_nanook/${reference_fasta} ${minion_folder}/reference_nanook/${reference_name}/

###Create symbolic links to working directories
cd ${minion_folder}/${project_name}
#Symbolic links to Poreminion working directories
find ${minion_folder}/${project_name}/downloads/fail/ -name '*.fast5' | xargs ln -sf --target-directory=${minion_folder}/${project_name}/fast5/fail/
find ${minion_folder}/${project_name}/downloads/pass/ -name '*.fast5' | xargs ln -sf --target-directory=${minion_folder}/${project_name}/fast5/pass/

###Use Poreminion to remove from the fail folder un-basecalled files and any base-called files that contained the time error where a block of events is repeated
echo 'Poreminion | Filtering reads...'
poreminion uncalled -m -o ${minion_folder}/${project_name}/uncalled-fail-filter ${minion_folder}/${project_name}/fast5/fail/
poreminion timetest -m -o ${minion_folder}/${project_name}/timetest-fail-filter ${minion_folder}/${project_name}/fast5/fail/

###Create symbolic links to working directories
echo 'Creating symbolic links for poreQC and poretools...'
cd ${minion_folder}/${project_name}
#Symbolic links to poreQC working directories
find ${minion_folder}/${project_name}/downloads/fail/ -name '*.fast5' | xargs ln -sf --target-directory=${minion_folder}/${project_name}/reads/downloads/fail/
find ${minion_folder}/${project_name}/downloads/pass/ -name '*.fast5' | xargs ln -sf --target-directory=${minion_folder}/${project_name}/reads/downloads/pass/
find ${minion_folder}/${project_name}/uploaded/ -name '*.fast5' | xargs ln -sf --target-directory=${minion_folder}/${project_name}/reads/
#Symbolic links to poretools working directories
find ${minion_folder}/${project_name}/downloads/pass/ -name '*.fast5' | xargs ln -sf --target-directory=${minion_folder}/${project_name}/poretools_temp/
find ${minion_folder}/${project_name}/downloads/fail/ -name '*.fast5' | xargs ln -sf --target-directory=${minion_folder}/${project_name}/poretools_temp/

###NanoOK
#Convert reads from fast5 to fasta and fastq
echo 'NanoOK | Converting fast5 to fasta and fastq...'
nanook extract -s ${minion_folder}/${project_name} -a #Command to convert in FASTA
nanook extract -s ${minion_folder}/${project_name} -q #Command to convert in FASTQ

###poreQC
#Run poreqc to generate statistics and plots of the sequencing run
echo 'poreQC | Generating stats and plots...'
python $poreqc_directory/poreqc.py --inrundir ${minion_folder}/${project_name} --refdir ${minion_folder}/reference_nanook/ --outdir ${minion_folder}/${project_name}/poreqc_analysis --outprefix $sample_name

###poretools
#Generate more statistics of the sequencing run
echo 'Poretools | Generating stats and plots...'
poretools stats ${minion_folder}/${project_name}/poretools_temp > ${minion_folder}/${project_name}/stats/poretools_stats.txt
poretools nucdist ${minion_folder}/${project_name}/poretools_temp > ${minion_folder}/${project_name}/stats/poretools_nucdist.txt
poretools qualdist ${minion_folder}/${project_name}/poretools_temp > ${minion_folder}/${project_name}/stats/poretools_qualdist.txt
poretools yield_plot --plot-type reads ${minion_folder}/${project_name}/poretools_temp --saveas ${minion_folder}/${project_name}/plots/poretools_total_reads_plot.png
poretools yield_plot --plot-type basepairs ${minion_folder}/${project_name}/poretools_temp --saveas ${minion_folder}/${project_name}/plots/poretools_total_bp_plot.png
poretools hist ${minion_folder}/${project_name}/poretools_temp --saveas ${minion_folder}/${project_name}/plots/poretools_total_reads_hist.png
poretools occupancy ${minion_folder}/${project_name}/poretools_temp --saveas ${minion_folder}/${project_name}/plots/poretools_pore_occupancy.png

###poreminion
#Generate more statistics and a summary of the sequencing run
echo 'Poreminion | Generating stats and summary...'
poreminion fragstats ${minion_folder}/${project_name}/fast5/pass > ${minion_folder}/${project_name}/stats/poreminion_stats.txt
#poreminion fragsummary -f ${minion_folder}/${project_name}/stats/poreminion_stats.txt > ${minion_folder}/${project_name}/stats/poreminion_onlypass_summary.txt
poreminion fragstats ${minion_folder}/${project_name}/fast5/fail >> ${minion_folder}/${project_name}/stats/poreminion_stats.txt
poreminion fragsummary -f ${minion_folder}/${project_name}/stats/poreminion_stats.txt > ${minion_folder}/${project_name}/stats/poreminion_summary.txt

###NanoOK
#Index reference LAST
echo 'NanoOK | Indexing reference...'
lastdb -Q 0 ${minion_folder}/reference_nanook/${reference_name} ${minion_folder}/reference_nanook/${reference_fasta}
#Alignment using LAST
echo 'NanoOK | Aligning with LAST...'
nanook align -s ${minion_folder}/${project_name} -r ${minion_folder}/reference_nanook/${reference_fasta} -aligner last
#Run NanoOK complete analysis
echo 'NanoOK | Generating report...'
nanook analyse -s ${minion_folder}/${project_name} -r ${minion_folder}/reference_nanook/${reference_fasta} -aligner last

echo '------------Script finished------------'