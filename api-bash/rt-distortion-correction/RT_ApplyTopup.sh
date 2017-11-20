#!/bin/bash
pathTopup=$1
pathToWatch=$2


# you can change this if you like:
mcpreface='RT_mc_'
dcmcpreface='RT_dcmc_'

# unzipped?? ([0 or 1])
# unzip you can leave on since it requires less time
# increases compatibility with SPM stuff
do_gunzip=1
dry_run=0


# the helper text,if no arguments are passed:
function showhelp() {
	echo 'RT_ApplyTopup.sh'
	echo '-------------'
	echo 
	echo 'Call this script after you have called RT_SetupTopup.sh:'
	echo
	echo '<PATH-TO-RT_SetupTopup>/RT_ApplyTopup.sh <PATH-TO-TOPUP-OUTPUT> <PATH-TO-WATCH>'
	echo
	echo 'This script will watch a folder for incoming files and operate on all Nifti files:'
	echo 'Except, of course, on .nii files that this script will generate in the same folder (!)'
	echo "I do this by regular exppression test on the filenames, starting with ${mcpreface}"
	echo "or with ${dcmcpreface}"
	echo
	echo 'First it will use mcflirt (with the mcref image in the Topup output path)'
	echo 'to estimate/correct for motion in real-time'
	echo "filenames will be: ${mcpreface}XXXX.nii"
	echo
	echo 'Second, it will use applytopup to apply distortion correction using topup_results'
	echo "in the Topup Output folder"
	echo "filenames will be: ${dcmcpreface}XXXX.nii"
	echo
	echo 'Both of these files will be present - so you can use whichever you want...'
	echo '.. for your further pipeline'
	echo 'The RT_mc_XXXX.nii files are generated in about <0.1 second'
	echo 'The RT_dcmc_XXXX.nii files take a bit longer (~0.5-0.6 seconds)'
	echo 'mcflirt will be done with ref image mcref.nii.gz, in the TOPUP-OUTPUT folder, that has'
	echo 'been pre-generated by SetupTopup. It is essentially the first of the UNcorrected'
	echo 'ge_ap images you put as input agrument to SetupTopup.sh'
	echo 
	echo 'Note of caution - it does not matter what the name is of incoming nifti files - '
	echo 'They are processed in the order in which they appear in!'
	echo

}



# first argument should be the path in which RT_SetupTopup did work
# second argument should be the path to operate on 'like f.e.: MRINCOMING'
if [ -z $1 ]; then
	showhelp
	exit 1
else
	echo "--------------"
	echo "Starting to watch for incoming fMRI volume files in: $pathToWatch"
	echo "Using Topup information in: $pathTopup"
	echo "--------------"
	# but ... we might need to do this so-called one-step-resampling, no?
   	# or how do we do it?
   	echo 'Implementation is currently with appytopup, but could be improved to appplywarp'
	echo 'Future implementation should be with applywarp for one-step resampling'
	echo 'And support of Motion Correction relative to First Incoming Volume'
	echo "--------------"
fi



# check whether everything is before doing anything: mcref.nii.gz topup_results_fieldcoef.nii.gz and mcref.nii.gz
for f in mcref.nii.gz topup_results_fieldcoef.nii.gz mcref.nii.gz; do
	if [ ! -f "$pathTopup/$f" ]; then
		echo "Error - cannot find $f: run RT_SetupTopup first"
		exit 1
	fi
done


img_count=0
inotifywait -m $pathToWatch -e create -e moved_to |
    while read path action file; do
        echo "The file '$file' appeared in directory '$path' via '$action'"
        
        # check whether file starts with a pre-ampble:
        if [[ $file = $mcpreface* ]] || [[ $file = $dcmcpreface* ]]; then
        	echo 'Doing nothing.. - file generated by RT_ApplyTopup'
		
        # check for nifti or niftigz
		elif [[ $file = *.nii* || $file = *.hdr* ]]; then

			# additional check for img/hdr files:
			if [[ $file = *.hdr ]]; then
				# wait for 0.05 seconds... for img to appear.
				sleep 0.05
				if [ ! -f $pathToWatch/${file/hdr/}img ]; then
					echo "Image didn't appear ... maybe change waiting/sleep time in the script"
					continue
				fi
			fi
			
			# do counter stuff + define names for later easier re-use with gunzip etc..
			img_count=$((img_count+1))
			img_number_string=$(printf "%04d" $img_count)
			
			# mc corrected volume
			mcvol=$pathToWatch/$mcpreface$img_number_string.nii.gz
			
			# dcmc corrected volume
			dcmcvol=$pathToWatch/$dcmcpreface$img_number_string.nii.gz
			
			# apply motion correction on file:
        	echo 'Image Detected - Applying Motion Correction'
        	echo " - Doing: " mcflirt -in $pathToWatch/$file -refvol $pathTopup/mcref.nii.gz -o $mcvol -mats -plots -spline_final
        	if [ ! $dry_run == 1 ]; then
        		mcflirt -in $pathToWatch/$file -refvol $pathTopup/mcref.nii.gz -o $mcvol -mats -plots -spline_final
        	fi
        	
        	if [ $do_gunzip -eq 1 ]; then
        		echo " - Doing: " gunzip $mcvol
				if [ ! $dry_run == 1 ]; then
					gunzip $mcvol
					mcvol=$pathToWatch/$mcpreface$img_number_string.nii
				fi
        	fi
        	
        	# apply distortion correction on file:
        	echo 'Applying Distortion Correction'
        	echo " - Doing: " applytopup --imain=$mcvol --inindex=1 --datain=$pathTopup/acqparams.txt --topup=$pathTopup/topup_results --out=$dcmcvol --method=jac
        	if [ ! $dry_run == 1 ]; then
        		applytopup --imain=$mcvol --inindex=1 --datain=$pathTopup/acqparams.txt --topup=$pathTopup/topup_results --out=$dcmcvol --method=jac
        	fi	

			if [ $do_gunzip -eq 1 ]; then
        		echo " - Doing: " gunzip $dcmcvol
        		if [ ! $dry_run == 1 ]; then
        			gunzip $dcmcvol
        			dcmcvol=$pathToWatch/$dcmcpreface$img_number_string.nii
        		fi
        	fi
        
        
        else
        	echo 'Doing Nothing!'
        fi
        	
        
        
    done

    

    

    