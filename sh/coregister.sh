#!/bin/bash

#--------------------------------------------------------------------------------------------------------


#  init.sh
#  brainmapper
#
#  Created by Allie on 2/3/13.
#  Copyright (c) 2013 University of Pennsylvania. All rights reserved.

RESPATH=$1
IMAGEPATH=$2
UPDATEPATH=$3
echo "Path to executables is $RESPATH, images is $IMAGEPATH, updateFile is $UPDATEPATH"
SEGMENT=$4
UNBURY=$5


# FSL Configuration (add FSL directory to path)
FSLDIR=${RESPATH}
echo $FSLDIR
PATH=${FSLDIR}/bin:${PATH}
#. ${FSLDIR}/etc/fslconf/fsl.sh

# Add binaries to path (add $RESPATH to path)
PATH=${RESPATH}:${PATH}
ANTSPATH=${RESPATH}/

export ANTSPATH PATH FSLDIR

#--------------------Below copied from fsh.sh-------------------------------
#  - note that the user should set

# Written by Mark Jenkinson
#  FMRIB Analysis Group, University of Oxford

# SHCOPYRIGHT


#### Set up standard FSL user environment variables ####

# The following variable selects the default output image type
# Legal values are:  ANALYZE  NIFTI  NIFTI_PAIR  ANALYZE_GZ  NIFTI_GZ  NIFTI_PAIR_GZ
# This would typically be overwritten in ${HOME}/.fslconf/fsl.sh if the user wished
#  to write files with a different format
FSLOUTPUTTYPE=NIFTI_GZ
export FSLOUTPUTTYPE

# Comment out the definition of FSLMULTIFILEQUIT to enable
#  FSL programs to soldier on after detecting multiple image
#  files with the same basename ( e.g. epi.hdr and epi.nii )
FSLMULTIFILEQUIT=TRUE ; export FSLMULTIFILEQUIT

FSLCONFDIR=$FSLDIR/config
#FSLMACHTYPE=`$RESPATH/fslmachtype.sh`

#export FSLCONFDIR FSLMACHTYPE


#echo "Path in init.sh is $PATH"
echo "this is a test update from coregister.sh. paths have been set." >> ${UPDATEPATH}


###################################################
####    DO NOT ADD ANYTHING BELOW THIS LINE    ####
###################################################

if [ -f /usr/local/etc/fslconf/fsl.sh ] ; then
. /usr/local/etc/fslconf/fsl.sh ;
fi


if [ -f /etc/fslconf/fsl.sh ] ; then
. /etc/fslconf/fsl.sh ;
fi


if [ -f "${HOME}/.fslconf/fsl.sh" ] ; then
. "${HOME}/.fslconf/fsl.sh" ;
fi

#------------------------------------------------------------


echo "setting more paths to images in coregister.sh" >> ${UPDATEPATH}
T1=${IMAGEPATH}/mri.nii.gz # pre-resection
template=${RESPATH}/NIREPG1template.nii.gz
templateLabels=${RESPATH}/NIREPG1template_35labels.nii.gz
warpOutputPrefix=NIREP # don't be the same as template file main body
CT=${IMAGEPATH}/ct.nii.gz # with electrodes
#T2=20070922_t2w003.nii.gz # post-resection
#resection=20070922_t2w003_resectedRegion.nii.gz
MRF_smoothness=0.1
electrode_thres=2000

# strip the skull in T1
echo "right now:stripping the skull in T1 in coregister.sh" >> ${UPDATEPATH}
echo "bet2 $T1 ${T1%.nii.gz}_brain -m"
echo "FSLOUTPUTTYPE $FSLOUTPUTTYPE"
#(bet = Brain Extraction Tool. this program strips away the skull and creats a binary mask of the brain that gets saved in the root mri_brain)
bet2 $T1 ${T1%.nii.gz}_brain -m
echo "10" >> ${UPDATEPATH}
echo Where even are you??? `pwd`







if [ $SEGMENT == 1 ] ; then
# warp the NIREP template to skull-stripped T1
echo "warping the NIREP template to skull-stripped T1 (this will take a few hours)" >> ${UPDATEPATH}
antsIntroduction.sh -d 3 -r $template -i ${T1%.nii.gz}_brain.nii.gz -o ${warpOutputPrefix}_ -m 30x90x20 -l $templateLabels
echo "15" >> ${UPDATEPATH}
# perform prior-based segmentation on the warped labels (may require more memory)
echo "performing prior-based segmentation on the warped labels (this will also take a few hours)" >> ${UPDATEPATH}
echo "35" >> ${UPDATEPATH}

mkdir priorBasedSeg
cd priorBasedSeg
for i in `seq 1 9`; do echo 0$i >> labels.txt; done
for i in `seq 10 35`; do echo $i >> labels.txt; done
for i in `cat labels.txt`
do
  ThresholdImage 3 ../${warpOutputPrefix}_labeled.nii.gz label${i}.nii.gz $i $i
  ImageMath 3 label_prob${i}.nii.gz G label${i}.nii.gz 3
done
echo "ImageMath completed; starting Atropos"
echo Just reminding you, Current Working Directory is: `pwd`
echo "50" >> ${UPDATEPATH}

#cp $T1 mri.nii.gz
#cp ${T1%.nii.gz}_brain_mask.nii.gz mri_brain_mask.nii.gz
#${T1%.nii.gz}_brain_mask.nii.gz

Atropos -d 3 -a $T1 -x ${T1%.nii.gz}_brain_mask.nii.gz -i PriorProbabilityImages[35,./label_prob%02d.nii.gz,0.5] -m [${MRF_smoothness},1x1x1] -c [5,0] -p Socrates[0] -o [./NIREP_seg35labels_prior0.5_mrf${MRF_smoothness}.nii.gz]
echo "70" >> ${UPDATEPATH}
cp NIREP_seg35labels_prior0.5_mrf${MRF_smoothness}.nii.gz ../seg35labels_prior0.5_mrf${MRF_smoothness}.nii.gz

cd ..
fi
# (now pwd is Debug)






# align CT to T1 and extract the electrodes
echo "Aligning CT to T1" >> ${UPDATEPATH}
echo Note that we are located at `pwd` and you should start seeing files that start with ct_ getting outputted here.
antsIntroduction.sh -d 3 -r $T1 -i $CT -o ${CT%.nii.gz}_ -t RA -s MI
echo "80" >> ${UPDATEPATH}
echo finished ANTS and starting c3d to finagle threshold and find electrodes and also output to electrode_aligned.
# extracting electrodes:
echo "Extracting electrodes with Convert3D" >> ${UPDATEPATH}
c3d ${CT%.nii.gz}_deformed.nii.gz -threshold ${electrode_thres} 99999 1 0 -o electrode_aligned.nii.gz



echo "90" >> ${UPDATEPATH}
#makeSpheres...if you unbury, you don't need this separately....
if [ $UNBURY != 1 ]; then 
c3d electrode_aligned.nii.gz -connected-components -split -foreach -centroid -endfor >> centroidFile.txt
cat centroidFile.txt | sed 's/[^0-9.]/ /g' >> eCenters.txt
c3d electrode_aligned.nii.gz -scale 0 -landmarks-to-spheres eCenters.txt 2 -o electrode_aligned.nii.gz
fi

#digElectrodes:
if [ $UNBURY == 1 ]; then
echo calling unbury.sh
${RESPATH}/unbury.sh electrode_aligned.nii.gz ${IMAGEPATH}/mri_brain_mask.nii.gz $RESPATH $UPDATEPATH
unbury="unburied_"
fi


echo "95" >> ${UPDATEPATH}
# combine electrodes with T1 segmentation
echo "combining electrodes with T1 segmentation and launching ITK-SNAP" >> UPDATEPATH
if [ $SEGMENT == 1 ]; then

c3d ${unburied}electrode_aligned.nii.gz -scale 40 seg35labels_prior0.5_mrf${MRF_smoothness}.nii.gz -add -clip 0 40 -o seg35labels_prior0.5_mrf${MRF_smoothness}_electro.nii.gz
cp ${unburied}seg35labels_prior0.5_mrf${MRF_smoothness}_electro.nii.gz ${IMAGEPATH}/finalImages/${unburied}electrode_seg.nii.gz
cd ${IMAGEPATH}
#Open ITK-SNAP in background so nothing freezes...
itksnap=/Applications/ITK-SNAP.app/Contents/MacOS/InsightSNAP
$itksnap -g $T1 -s ${unburied}electrode_seg.nii.gz -l segmentedLabels_preResec.txt &
fi

# but if you don't want it segmented, then don't deal with the seg35labels_ files...
if [ $SEGMENT != 1 ]; then

c3d ${unburied}electrode_aligned.nii.gz -scale 2 ${IMAGEPATH}/mri_brain_mask.nii.gz -add -clip 0 2 -o ${unburied}electrode_seg.nii.gz
cp ${unburied}electrode_seg.nii.gz ${IMAGEPATH}/${unburied}electrode_seg.nii.gz
cd ${IMAGEPATH}
#Open ITK-SNAP in background so nothing freezes...
itksnap=/Applications/ITK-SNAP.app/Contents/MacOS/InsightSNAP
$itksnap -g $T1 -s ${unburied}electrode_seg.nii.gz -l unsegmentedLabels.txt &
fi


echo "100" >> ${UPDATEPATH}




#------------------------------------------------------------------------------------------------------
## POST-RESECTION ONLY - not supported in the mac app (yet?)
## aligned post-resection T2 to (pre-resection) T1
#./antsIntroduction.sh -d 3 -r $T1 -i $T2 -o ${T2%.nii.gz}_ -t RI -s MI

## transform resected region from post-resection T2 to (pre-resection) T1
#WarpImageMultiTransform 3 $resection ${resection%.nii.gz}_aligned.nii.gz -R $T1 ${T2%.nii.gz}_Affine.txt

## combine the resected cortex (brain mask minus resection) and the electrodes
#c3d ${T1%.nii.gz}_brain_mask.nii.gz ${resection%.nii.gz}_aligned.nii.gz -thresh 0.99 99 2 0 -add -clip 0 2 electrode_aligned.nii.gz -scale 3 -add -clip 0 3 -o ElectrodesOnResectedCortex.nii.gz
