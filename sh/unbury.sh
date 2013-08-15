#!/bin/bash

#  unbury.sh
#  brainmapper
#
#  Created by Veena Krish on 7/22/13.
#  Copyright (c) 2013 University of Pennsylvania. All rights reserved.

IMAGEPATH=$1
RESPATH=$2
UPDATEPATH=$3

# Add binaries to path in case they weren't there (add $RESPATH to path and export again; hopefully no one will complain)
PATH=${RESPATH}:${PATH}
export PATH

#--------------------------------------------------------------------------------------------------------
cd $IMAGEPATH
echo We Are At: $PWD

# 1. unload files

c3d ${IMAGEPATH}/electrode_aligned.nii.gz -binarize -o eImg.img
c3d ${IMAGEPATH}/mri_brain.nii.gz -binarize -o bImg.img
#(not sure if these are needed, but anyway...)



#2. get centroids:
numCOMPS=$(c3d eImg.img -comp | head -n 1 | sed 's/[^0-9]/ /g')
#IF NOTHING COMPLAINS ABOUT THIS ONE PROCESS, REJOICE IN YOUR COMPUTING POWER AND RAM:
echo Before first c3d `date`
c3d eImg.img -connected-components -split -foreach -centroid -endfor | sed -e '/VOX/d' -e 's/[^0-9.-]/ /g' >> eCent.txt #(this gets centroids, in mm's)
RETURNCOND=$?
echo entire c3d -comp returned $RETURNCOND
if [ $RETURNCOND -ne 0 ]; then
echo Before second c3d `date`

#first figure out how many connected regions there are.
let "numRepeats = $numCOMPS / 30 + 1"
#then find centroids in batches of 30 connected regions so you don't run into memory problems
echo "Locating electrodes for Unburying (hang on...this will take a minute)" >> $UPDATEPATH
for i in `seq 0 $(expr $numRepeats - 1)`; do
uIn=$(expr 30 \* $i)
echo $uIn
c3d eImg.img -comp -threshold $uIn $(expr $uIn + 29) 1 0 -comp -split -foreach -centroid -endfor >> eCent.txt
done
c3d eImg.img -comp -threshold $uIn $(expr $numCOMPS) 1 0 -comp -split -foreach -centroid -endfor >> eCent.txt
echo $uIn >> eCent.txt
fi


cat eCent.txt | sed -e '/VOX/d' -e '/There/d' -e '/Largest/d' -e 's/[^0-9.-]/ /g' >> eCenters.txt #(this gets rid of unneccessary info in the txt file)


#read eCenters.txt into an array: (never mind; this isn't that helpful)
#cat eCenters.txt | awk '{print $1}' >> eCentersX.txt
#cat eCenters.txt | awk '{print $2}' >> eCentersY.txt
#cat eCenters.txt | awk '{print $3}' >> eCentersZ.txt
#eCentersX=( `cat "eCentersX.txt" `)
#eCentersY=( `cat "eCentersY.txt" `)
#eCentersZ=( `cat "eCentersZ.txt" `) #(is this at all faster?)
#rm eCentersX.txt eCentersY.txt eCentersZ.txt



#3. now that you have the list of electrodes, eCent.txt, get the brain's center of mass: bCOM, in physical mm's
c3d bImg.img -centroid | sed -e '/VOX/d' -e 's/[^0-9.-]/ /g' >> bCOM
BCOMS=( `cat bCOM` )
#(the x-centerOfMass is in ${BCoMs[0]}; the y-centerOfMass is in ${BCoMs[1]}...)


#4. get the directions in which each electrode needs to travel to resurface. (the file 'directions' has 3 col's: x, y, and z components of the dir vector for each electrode
cat eCenters.txt | awk -v x=${BCOMS[0]} -v y=${BCOMS[1]} -v z=${BCOMS[2]} '{ printf("%f %f %f\n",$1-x, $2-y, $3-z) }' >> directions


#5. AND NOW FOR EACH ELECTRODE, retrieve its direction vector in lowest termss
NUMELECTRODES=$( cat directions | wc -l )
for i in `seq 1 $NUMELECTRODES`; do
    eDir=(`sed -n "${i}p" < directions`)
    dirX=${eDir[0]}
    dirY=${eDir[1]}
    dirZ=${eDir[2]} #(there's prob a better way to do this)

#   a=$dirX
#   b=$dirY
#    c=$dirZ
#    r=1 #(get the gcd...)
#    until [ $r == 0 ]; do let "r= $a % $b"; a=$b; b=$r; done
#    r=1
#    until [ $r == 0 ]; do let "r= $a % $c"; a=$c; c=$r; done
#    gcd=$a
#let "dirX=dirX/gcd" "dirY=dirY/gcd" "dirZ=dirZ/gcd"

    #get the electrode's CoM from the big file
    eCOMS=(`sed -n "${i}p" < eCenters.txt`)
    eCOMx=${eCOMS[0]}
    eCOMy=${eCOMS[1]}
    eCOMz=${eCOMS[2]}


#TRY: instead of reducing to lowest terms with the gcd, just normalize the vector....I'm doing this in physical mm's so having decimals shouldn't matter.
norm=$( echo "scale=10; ${dirX}^2 + ${dirY}^2 + ${dirZ}^2" | bc )
norm=$( echo "scale=10; sqrt($norm)" | bc )

dirX=$( echo "scale=10; $dirX / $norm" | bc )
dirY=$( echo "scale=10; $dirY / $norm" | bc )
dirZ=$( echo "scale=10; $dirZ / $norm" | bc )


#and get the "step": the direction in increments...
distance=$( echo "scale=4; sqrt((${eCOMS[0]} - ${dirX})^2 + (${eCOMS[1]} - ${dirY}) ^2 + (${eCOMS[2]} - ${dirZ})^2 )" | bc);
stepX=$( echo "scale=4; 100 * ${dirX} / (${distance} - 1)" | bc);
stepY=$( echo "scale=4; 100 * ${dirY} / (${distance} - 1)" | bc);
stepZ=$( echo "scale=4; 100 * ${dirZ} / (${distance} - 1)" | bc);
echo "$stepX $stepY $stepZ" >> steps

echo Before loop `date`


    #AND NOW THE ACTUAL TESTING: #7. Create a path from bCOM in the direction of each electrode's eDir
    value=1
    until [ $value -eq 0 ]; do
        newPoint=$eCOMx\ $eCOMy\ $eCOMz
        value=$( c3d bImg.img -probe ${eCOMx}x${eCOMy}x${eCOMz}mm | awk '{ print substr($0,length,1) }' )
        status=$?
        if [ "$status" != 0 ]; then break
        elif [ "$value" == 1 ]; then
            eCOMx=$( echo "scale=4; ${eCOMx}+${stepX}" | bc);
            eCOMy=$( echo "scale=4; ${eCOMy}+${stepY}" | bc);
            eCOMz=$( echo "scale=4; ${eCOMz}+${stepZ}" | bc);
            continue
        fi
        break
    done
    echo "$newPoint 1" >> landmarks
    echo $i $newPoint landmarked

done

echo after loop `date`

#8. AND FINALLY
c3d eImg.img -scale 0 -landmarks-to-spheres landmarks 2 -o landmarked.img
c3d landmarked.img -o unburied_electrode_aligned.nii.gz




