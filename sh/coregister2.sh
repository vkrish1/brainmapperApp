#!/bin/bash

# important parts of coregister.sh

RESPATH=$1
IMAGEPATH=$2
UPDATEPATH=$3
echo "Path to executables is $RESPATH, images is $IMAGEPATH, updateFile is $UPDATEPATH"
SEGMENT=$4
UNBURY=$5

# FSL Configuration
FSLDIR=${RESPATH}
echo $FSLDIR
PATH=${FSLDIR}/bin:${PATH}
#. ${FSLDIR}/etc/fslconf/fsl.sh

# Add binaries to path
PATH=${RESPATH}:${PATH}
ANTSPATH=${RESPATH}/

export ANTSPATH PATH FSLDIR






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
T1=${IMAGEPATH}/mri.nii.gz # pre-resection WAIT THIS DOESN'T EXIST??????????
template=${RESPATH}/NIREPG1template.nii.gz
templateLabels=${RESPATH}/NIREPG1template_35labels.nii.gz
warpOutputPrefix=NIREP # don't be the same as template file main body
CT=${IMAGEPATH}/ct.nii.gz # with electrodes
electrode_thres=2000
#T2=20070922_t2w003.nii.gz # post-resection
#resection=20070922_t2w003_resectedRegion.nii.gz
MRF_smoothness=0.1



# skipping: skull stripping in T1, warping NIREP template to it. now: priorSeg

echo "performing prior-based segmentation on the warped labels (this will also take a few hours)" >> ${UPDATEPATH}
echo Just reminding you, Current Working Directory is: `pwd`
cd priorBasedSeg
for i in `cat labels.txt`
do
  ImageMath 3 label_prob${i}.nii.gz G label${i}.nii.gz 3
done
echo "ImageMath completed; starting Atropos" >> ${UPDATEPATH}


