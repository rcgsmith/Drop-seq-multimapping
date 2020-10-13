#!/bin/bash
#Script to process single bam file (clean_star_gene_exon.bam)

#samtools collate function collects alignments by query name ie template - but output is not sorted overall by QNAME therefore is faster than samtools sort -n

#This part can take a long time and needs space for temporary files
echo $(date -u) "Query collating.." | tee -a $logfile
samtools collate -O $alteration_input $mm_out_dir/temp_collate > $mm_out_dir/temp/temp_QNAMECollated.bam 
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Query collating" exit $rc; fi
echo $(date -u) "Query collated" | tee -a $logfile

#Get header - when awk a sam file you lose the header. Output is a sam file.
#Need to change header - @PG line which gives details of the program used to create samfile, has -- to indicate program options. 
#However, this causes problems with merging sam files later on, change -- to DS: which is a description tag
# -- only occurs in @PG header line
echo $(date -u) "Creating header.." | tee -a $logfile
samtools view -H $mm_out_dir/temp/temp_QNAMECollated.bam | awk '/@PG/ {gsub(/\-\-/, "DS:")} {print}' > $mm_out_dir/temp/header.sam
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Creating header" exit $rc; fi

echo $(date -u) "Header created" | tee -a $logfile 

#Filter bam file for mapq values (-q). stdout is mapq > 255, -U output is mapq <255. Outputs are bam files
echo $(date -u) "Finding Unique and NonUnique alignments.." | tee -a $logfile
samtools view -b -q 255 -U $mm_out_dir/temp/tempNonUnique.bam -o $mm_out_dir/temp/tempUnique.bam $mm_out_dir/temp/temp_QNAMECollated.bam 
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Finding Unique and NonUnique alignments" exit $rc; fi


echo $(date -u) "Finding Dual alignments.." | tee -a $logfile
#Find dual mappers, by skipping mapq<3 (-q). Output is headered sam file
samtools view -b -q 3 -U $mm_out_dir/temp/tempOverDual.bam -o $mm_out_dir/temp/tempDual.bam $mm_out_dir/temp/tempNonUnique.bam 

echo $(date -u) "Finding Triple and Quad alignments.." | tee -a $logfile
#Find triple/quad mappers (with mapq 1) and print NH:i:4 lines to tempQuad.sam and standard output (triple mappers) to tempTriple.bam
samtools view -q 1 $mm_out_dir/temp/tempOverDual.bam | awk '/NH:i:3/' | cat $mm_out_dir/temp/header.sam - | samtools view -S -b -o $mm_out_dir/temp/tempTriple.bam  
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Finding Triple alignments" exit $rc; fi

samtools view -q 1 $mm_out_dir/temp/tempOverDual.bam | awk '/NH:i:4/' | cat $mm_out_dir/temp/header.sam - | samtools view -S -b -o $mm_out_dir/temp/tempQuad.bam 
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Finding Quad alignments" exit $rc; fi

#remove any orphan alignments
echo $(date -u) "Finding orphan dual alignments." | tee -a $logfile
samtools view $mm_out_dir/temp/tempDual.bam | awk '{if (x[$1]) { x_count[$1]++; print $0; if (x_count[$1] == 1) { print x[$1] } } x[$1] = $0}' | cat $mm_out_dir/temp/header.sam - > $mm_out_dir/temp/tempNoOrphansDual.sam
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Finding orphan dual alignments" exit $rc; fi
echo $(date -u) "Orphan dual alignments removed." | tee -a $logfile 

#remove incomplete alignment sets eg. 1 or 2 alignments in Triple, 1,2,or 3 alignments in Quad
echo $(date -u) "Finding orphan triple alignments." | tee -a $logfile
samtools view $mm_out_dir/temp/tempTriple.bam |  awk '{if (x1[$1]) { x_count[$1]++; if ( x_count[$1]==2 ) { print x2[$1]; print x1[$1]; print $0 } }; x2[$1]= x1[$1]; x1[$1] = $0}' | cat $mm_out_dir/temp/header.sam - > $mm_out_dir/temp/tempNoOrphansTriple.sam
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Finding orphan triple alignments" exit $rc; fi

echo $(date -u) "Orphan triple alignments removed." | tee -a $logfile

echo $(date -u) "Finding orphan quad alignments." | tee -a $logfile
samtools view $mm_out_dir/temp/tempQuad.bam |  awk '{if (x1[$1]) { x_count[$1]++; if ( x_count[$1]==3 ) { print x3[$1]; print x2[$1]; print x1[$1]; print $0 } };  x3[$1]=x2[$1]; x2[$1]= x1[$1]; x1[$1] = $0}' | cat $mm_out_dir/temp/header.sam - > $mm_out_dir/temp/tempNoOrphansQuad.sam
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Finding orphan quad alignments" exit $rc; fi

echo $(date -u) "Orphan quad alignments removed." | tee -a $logfile

#Remove large, unneeded bam files
rm $mm_out_dir/temp/temp_QNAMECollated.bam
rm $mm_out_dir/temp/tempDual.bam
rm $mm_out_dir/temp/tempOverDual.bam
rm $mm_out_dir/temp/tempTriple.bam
rm $mm_out_dir/temp/tempQuad.bam
rm $mm_out_dir/temp/tempNonUnique.bam

#Altering alignment mapq score
echo $(date -u) "Altering dual alignments.." | tee -a $logfile
#Need --posix option when implementing AScompare.awk because if running gawk then need --posix for regular expressions as AScompare.awk is developed on BSD awk.
#Pipe sam output of cat into samtools view with output as bam.
samtools view -S $mm_out_dir/temp/tempNoOrphansDual.sam | awk --posix -f $multifolder/AScompareDual.awk | cat $mm_out_dir/temp/header.sam - | samtools view -S -b -o $mm_out_dir/temp/tempAlteredDual.bam -
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Altering Dual alignments" exit $rc; fi
echo $(date -u) "Dual alignments altered and saved as bam file" | tee -a $logfile

echo $(date -u) "Altering triple alignments.." | tee -a $logfile
#Need --posix option when implementing AScompare.awk because if running gawk then need --posix for regular expressions as AScompare.awk is developed on BSD awk.
#Pipe sam output of cat into samtools view with output as bam.
samtools view -S $mm_out_dir/temp/tempNoOrphansTriple.sam | awk --posix -f $multifolder/AScompareTriple.awk | cat $mm_out_dir/temp/header.sam - | samtools view -S -b -o $mm_out_dir/temp/tempAlteredTriple.bam -
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Altering Triple alignments" exit $rc; fi
echo $(date -u) "Triple alignments altered and saved as bam file" | tee -a $logfile

echo $(date -u) "Altering quadruple alignments.." | tee -a $logfile
#Need --posix option when implementing AScompare.awk because if running gawk then need --posix for regular expressions as AScompare.awk is developed on BSD awk.
#Pipe sam output of cat into samtools view with output as bam.
samtools view -S $mm_out_dir/temp/tempNoOrphansQuad.sam | awk --posix -f $multifolder/AScompareQuad.awk | cat $mm_out_dir/temp/header.sam - | samtools view -S -b -o $mm_out_dir/temp/tempAlteredQuad.bam -
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Altering Quad alignments" exit $rc; fi
echo $(date -u) "Quad alignments altered and saved as bam file" | tee -a $logfile

#Remove large, unneeded bam files
rm $mm_out_dir/temp/tempNoOrphansDual.sam
rm $mm_out_dir/temp/tempNoOrphansTriple.sam
rm $mm_out_dir/temp/tempNoOrphansQuad.sam

#merge Dual_altered etc. and Unique (-c -p indicate that should not be duplicate @RG or @PG header lines
echo  $(date -u) "Merging Unique and Dual altered bam files, sort by coordinate.."  | tee -a $logfile
samtools merge -f -c -p - $mm_out_dir/temp/tempUnique.bam $mm_out_dir/temp/tempAlteredDual.bam $mm_out_dir/temp/tempAlteredTriple.bam $mm_out_dir/temp/tempAlteredQuad.bam | samtools sort -o $outputfile - 
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Merging files" exit $rc; fi
#index the bam file
samtools index -b $outputfile
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON indexing" exit $rc; fi
echo $(date -u) "Merged"  | tee -a $logfile

#Get Stats on alterations:
#Take XR tags from TagCollection.awk then totalXRtagsbyGene.awk and manipulate in shell

#get GE and XR tags for dual, triple and quad bams
echo $(date -u) "Generating GEXRtag files" | tee -a $logfile
samtools view $mm_out_dir/temp/tempAlteredDual.bam | awk --posix -f $multifolder/TagCollection.awk > $mm_out_dir/temp/Dual_GEXRtags.txt
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Generating Dual GEXRtag files" exit $rc; fi
samtools view $mm_out_dir/temp/tempAlteredTriple.bam | awk --posix -f $multifolder/TagCollection.awk > $mm_out_dir/temp/Triple_GEXRtags.txt
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Generating Triple GEXRtag files" exit $rc; fi
samtools view $mm_out_dir/temp/tempAlteredQuad.bam | awk --posix -f $multifolder/TagCollection.awk > $mm_out_dir/temp/Quad_GEXRtags.txt
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Generating Quad GEXRtag files" exit $rc; fi

#Remove unneeded bams
rm $mm_out_dir/temp/tempAlteredDual.bam
rm $mm_out_dir/temp/tempAlteredTriple.bam
rm $mm_out_dir/temp/tempAlteredQuad.bam
rm $mm_out_dir/temp/tempUnique.bam

#Frequencies of GE tag type for EACH XR tag type
echo $(date -u) "Generating GEtags_XRfrequencies" | tee -a $logfile
cat $mm_out_dir/temp/Dual_GEXRtags.txt $mm_out_dir/temp/Triple_GEXRtags.txt $mm_out_dir/temp/Quad_GEXRtags.txt | sort | uniq -c > $mm_out_dir/GEtags_XRfrequencies.txt
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON GEtags_XRfrequencies" exit $rc; fi

#Frequencies of GE tag type for ALL XR tag types
echo $(date -u) "Generating GEtags_XRtotals" | tee -a $logfile
awk --posix -f $multifolder/totalXRtagsbyGene.awk $mm_out_dir/GEtags_XRfrequencies.txt | sort -k1 -n -r > $mm_out_dir/GEtags_XRtotals.txt
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Generating GEtags_XRtotals" exit $rc; fi


#Total Frequencies of XR tag type regardless of GE tag
echo $(date -u) "Generating XRtags_totals" | tee -a $logfile
cat $mm_out_dir/temp/Dual_GEXRtags.txt $mm_out_dir/temp/Triple_GEXRtags.txt $mm_out_dir/temp/Quad_GEXRtags.txt | cut -f2 | sort | uniq -c > $mm_out_dir/XRtags_totals.txt
### if previous step failed - exit
rc=$?; if [[ $rc != 0 ]]; then echo "FAILED ON Generating XRtags_totals" exit $rc; fi


rm $mm_out_dir/temp/header.sam
rm $mm_out_dir/temp/Dual_GEXRtags.txt
rm $mm_out_dir/temp/Triple_GEXRtags.txt
rm $mm_out_dir/temp/Quad_GEXRtags.txt



 

