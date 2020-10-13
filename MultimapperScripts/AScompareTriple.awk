# MIT License
# Copyright 2020 rcgsmith (Rosanna Smith)

#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#Script to alter 'primary' flag for appropriate alignments when have triple alignments for given queryname
BEGIN{ 

}

##FUNCTIONS 

#adapted from https://www.gnu.org/software/gawk/manual/html_node/Join-Function.html
#joins whole array with tab delimiters

function join(array, n, result, i) {
	result= array[1]
    	for (i=2; i<=n; i++){
        	result= result"\t"array[i]
	}
    	return result
}

function joinnospace(array, n, result, i) {
        result= array[1]
        for (i=2; i<=n; i++){
                result= result array[i]
        }
        return result
}

#Binary converter from https://stackoverflow.com/questions/18870209/convert-a-decimal-number-to-hexadecimal-and-binary-in-a-shell-script
function Dec2Bin(decimal, r,  a, result) {
	r=""                    # initialize result to empty (not 0)
      	a=decimal               # get the number
      	while(a!=0){            # as long as number still has a value
  	      r=((a%2)?"1":"0") r   # prepend the modulos2 to the result
        	a=int(a/2)            # shift right (integer division by 2)
      	}
      	result=sprintf("%011d",r)       # print result with fixed width of 11 (sam flag has 11 bitwise flags). Rightmost digit is first flag, leftmost digit is 11th flag.   
	return result
}

#Convert from binary back to decimal (http://blog.nextgenetics.net/?e=18), 1st digit in binary is the higest ie. mth power of 2:
function Bin2Dec(binary, splitbinary, m, oldtotal, newtotal, result){
	m=split(binary, splitbinary, "")		#split binary number into array - m is number of elements (should be 11)
	oldtotal=0				#initialise running total	
	for(k=m;k>=1;k--){			#For each element of array add contribution to total decimal number
		ithpower=splitbinary[m-k+1]*(2^(k-1))		#1st element of array is 11th bitwise flag (0 or 1), which is (0 or 1)*2^10 ie array[1]*2^(m-1) 
		newtotal=oldtotal + ithpower			#2nd element of array is 10th bitwise flag (0 or 1), which is (0 or 1)*2^9 ie array[2]*2^(m-2) 
		oldtotal=newtotal
	}
	result=oldtotal
	return result
}

function myXOR(a,b,result){
	result=((a && !b) || (!a && b)) 
	return result
}

function ChangeSecondaryFlags(k, indexChange, XRtag){
	for (i=1; i<=k; i++){
              	       if (i==indexChange){

                        	#make sure indexChange alignment is primary (P) alignment:
                                nP=split(ArrayLine[i], splitlineP)
                            	splitlineP[nP+1]= XRtag
                                nbinaryP=split(ArrayBinaryFlag[i], splitbinaryflagP, "")
                                splitbinaryflagP[3]=0
                                ArrayBinaryFlag[i]=joinnospace(splitbinaryflagP, nbinaryP)
                                ArrayFlag[i]=Bin2Dec(ArrayBinaryFlag[i])
                                splitlineP[2]=ArrayFlag[i]
                                ArrayLine[i]=join(splitlineP, nP+1)

                        }

                       else {	
                             #make sure other alignments have secondary (S) flag (indicating secondary alignment):
                              nS=split(ArrayLine[i], splitlineS)
                              nbinaryS=split(ArrayBinaryFlag[i], splitbinaryflagS, "")
                              splitbinaryflagS[3]=1
                              ArrayBinaryFlag[i]=joinnospace(splitbinaryflagS, nbinaryS)
                              ArrayFlag[i]=Bin2Dec(ArrayBinaryFlag[i])
                              splitlineS[2]=ArrayFlag[i]
                              ArrayLine[i]=join(splitlineS, nS)

                       }
          }	
}


###MAIN PROGRAM

{
#Find AS tag
match($0,/AS:i:../) 
ASvalue=substr($0,RSTART+5,2)

#Find XF tag (every alignment should have XF tag I think)

match($0, /XF:[A-Z]:[A-Z]{1,20}/)
XFvalue=substr($0, RSTART+5, RLENGTH-5)

#Set GEvalue to GE tag if CODING or UTR, or "" otherwise
if (XFvalue=="CODING" || XFvalue=="UTR"){
       	match($0, /GE:[A-Z]:[a-zA-Z0-9\^\.\*\(\)-]{1,50}/)
     	GEvalue=substr($0, RSTART+5, RLENGTH-5)
}
else GEvalue=""

#Convert to decimal using own function Dec2Bin, then take 3rd character, which is actually 9th Sam flag, indicating if alignment is secondary
#Secondary Flag = 1 means is not Primary, Seconary Flag = 0 means is primary

BinaryFlag=Dec2Bin($2)

if (NR % 3 ==0){
	ArrayASvalue[1]=ASvalue
	ArrayXFvalue[1]=XFvalue
	ArrayGEvalue[1]=GEvalue
	ArrayFlag[1]=$2
	ArrayBinaryFlag[1]=BinaryFlag
	ArrayLine[1]=$0
	XFflag=0
        for (i=1; i<=3; i++){
                if ((ArrayXFvalue[i]=="CODING" || ArrayXFvalue[i]=="UTR") && !ArrayGEvalue[i]){XFflag=1}
        }
}

#For 2max AS values:
twomaxGEcount=0


#Work with triplets of lines, therefore assess every 3rd line lines. If on other lines, simply store previous lines and store values in array

#If any of the alignments are XF:Z:CODING but do not have a GE tag, then do not want to alter anything as could be introducing bias as have incomplete information. (Conservative stance)
if (NR % 3 ==0  && XFflag==1) {
	#Need to make sure all alignments have secondary flag:
        for (i=1; i<=3; i++){
                n=split(ArrayLine[i], splitline)
                nbinary=split(ArrayBinaryFlag[i], splitbinaryflag, "")
                if (splitbinaryflag[3]==0){
                        splitbinaryflag[3]=1
                        ArrayBinaryFlag[i]=joinnospace(splitbinaryflag, nbinary)
                        ArrayFlag[i]=Bin2Dec(ArrayBinaryFlag[i])
                        splitline[2]=ArrayFlag[i]
                        splitline[n+1]="XR:Z:Triple_XFnoGE_conditionsNOTsatisfied"
                        ArrayLine[i]=join(splitline, n+1)
                }
        }
	
	print ArrayLine[3]
        print ArrayLine[2]
        print ArrayLine[1]
}

#ASvalue DIFFERENT - there is at least one lastASvalue which is not the same as this ASvalue
else if ((NR % 3 ==0 && XFflag==0) && (ArrayASvalue[1]!= ArrayASvalue[2] || ArrayASvalue[1]!=ArrayASvalue[3])){
	maxASvalue=""
	max2ASvalue=""
	maxASindex=""
	max2ASindex=""
	
	#create indices for AS values:
      	#ASvalue with index for maximum ASvalue
	for (i=1; i<=3; i++){
		if (maxASvalue < ArrayASvalue[i]) {
			maxASvalue=ArrayASvalue[i] 
			maxASindex=i			
		}	
	}

	#Is there another with same max AS value?		
	for (j=1; j<=3; j++){
		if ((maxASvalue == ArrayASvalue[j]) && (j != maxASindex)){
			max2ASindex=j
                }
	}

	#Define indices for non-maxAS values when only one max value
	if (!max2ASindex){
		if (maxASindex==1){
			lowASindex1=2
			lowASindex2=3
		}
		if (maxASindex==2){
         	      	lowASindex1=1
                	lowASindex2=3
        	}
		if (maxASindex==3){
                	lowASindex1=1
                	lowASindex2=2
        	}
	}
	#Define indices for non-maxAS values when two max values
	if (max2ASindex && maxASindex){
		lowASindex1=6-max2ASindex-maxASindex
	}

	#When have ONE maxASvalue:
	if  (!max2ASindex){
		#If GEvalue exists it means that alignment must be CODING/UTR, if not, then is INTERGENIC/INTRONIC or is on wrong strand of coding region
                #max AS value alignment is coding and others are not:
		if ( ArrayGEvalue[maxASindex] && !ArrayGEvalue[lowASindex1] && !ArrayGEvalue[lowASindex2]){
                        #CHANGE MAX AS alignment 
			#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3],"\t maxindex","\t", maxASindex, "\t lowindex1","\t", lowASindex1, "\t lowindex2", "\t",lowASindex2, "\t 1max_oneCODING","\t", ArrayGEvalue[maxASindex]

			ChangeSecondaryFlags(3, maxASindex, "XR:Z:Triple_1max_ONLYmaxCODING")

			for (i=3; i>=1; i--){
				if(i==maxASindex){print ArrayLine[maxASindex]}
                        	if(i==lowASindex1){print ArrayLine[lowASindex1]}
                        	if(i==lowASindex2){print ArrayLine[lowASindex2]}
			}       
		}

		#all alignments are coding, with same GEvalue ie. max GE value exists and equals others
		#or one max GEvalue and one of low GEvalues are the same, with the other being noncoding.
		else if ( (ArrayGEvalue[maxASindex] && (ArrayGEvalue[maxASindex] == ArrayGEvalue[lowASindex1]) && (ArrayGEvalue[maxASindex] == ArrayGEvalue[lowASindex2]) )\
			|| (ArrayGEvalue[maxASindex] && (ArrayGEvalue[maxASindex] == ArrayGEvalue[lowASindex1]) && !ArrayGEvalue[lowASindex2])\
			|| (ArrayGEvalue[maxASindex] && (ArrayGEvalue[maxASindex] == ArrayGEvalue[lowASindex2]) && !ArrayGEvalue[lowASindex1]) ) {
			#CHANGE MAX AS alignment
			#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3], "\t maxindex", "\t", maxASindex, "\t lowindex1","\t", lowASindex1, "\t lowindex2", "\t", lowASindex2, "\t 1max_allortwoCODING", "\t", ArrayGEvalue[maxASindex]
			
			ChangeSecondaryFlags(3, maxASindex, "XR:Z:Triple_1max_allortwoCODING_GEsame")
			
			for (i=3; i>=1; i--){
                                if(i==maxASindex){print ArrayLine[maxASindex]}
                                if(i==lowASindex1){print ArrayLine[lowASindex1]}
                                if(i==lowASindex2){print ArrayLine[lowASindex2]}
                        }
		}
		else {
			#Conditions to include alignments are not satisfied, make sure all primary alignments are changed to secondary - otherwise primary alignments will be included in DGE.
                        #print ArrayASvalue[1]," ", ArrayASvalue[2], " ", ArrayASvalue[3], " maxindex", maxASindex, "lowindex1", lowASindex1, "lowindex2", lowASindex2, "1max_conditionsNOTsatisfied"
                      	for (i=1; i<=3; i++){
                                n=split(ArrayLine[i], splitline)
                                nbinary=split(ArrayBinaryFlag[i], splitbinaryflag, "")
                                if (splitbinaryflag[3]==0){
                                        splitbinaryflag[3]=1
                                        ArrayBinaryFlag[i]=joinnospace(splitbinaryflag, nbinary)
                                        ArrayFlag[i]=Bin2Dec(ArrayBinaryFlag[i])
                                        splitline[2]=ArrayFlag[i]
                                        splitline[n+1]="XR:Z:Triple_1max_conditionsNOTsatisfied"
                                        ArrayLine[i]=join(splitline, n+1)
                                }
                	}

			for (i=3; i>=1; i--){
                                if(i==maxASindex){print ArrayLine[maxASindex]}
                                if(i==lowASindex1){print ArrayLine[lowASindex1]}
                                if(i==lowASindex2){print ArrayLine[lowASindex2]}
                        }
                }

	}	
	
	#When have TWO maxASvalues:
	else if  (max2ASindex){
		# determine 2maxGEcount for two coding alignments
		#max GEvalue and max2 GEvalue and lowindex1 GE value are all coding and the same
		# OR max and max2 coding and the same, lowindex1 noncoding 
		# OR max and lowindex1 coding and the same, max2 noncoding 
		# OR max2 and lowindex1 coding and the same, max noncoding

		if ((ArrayGEvalue[maxASindex] && (ArrayGEvalue[maxASindex] == ArrayGEvalue[max2ASindex])) && (ArrayGEvalue[maxASindex] == ArrayGEvalue[lowASindex1])){twomaxGEcount=1}
		else if ((ArrayGEvalue[maxASindex] && (ArrayGEvalue[maxASindex] == ArrayGEvalue[max2ASindex])) && !ArrayGEvalue[lowASindex1]){twomaxGEcount=1}
                else if ((ArrayGEvalue[maxASindex] && (ArrayGEvalue[maxASindex] == ArrayGEvalue[lowASindex1])) && !ArrayGEvalue[max2ASindex]){twomaxGEcount=1}
                else if ((ArrayGEvalue[max2ASindex] && (ArrayGEvalue[max2ASindex] == ArrayGEvalue[lowASindex1])) && !ArrayGEvalue[maxASindex]){twomaxGEcount=1}
             
		#max GEvalue is coding and max2 and lowindex1 are noncoding
		# OR max2 GEvalue is coding and max and lowindex1 are noncoding
		if ((( ArrayGEvalue[maxASindex] && !ArrayGEvalue[max2ASindex]) && !ArrayGEvalue[lowASindex1])\
		 || ((ArrayGEvalue[max2ASindex] && !ArrayGEvalue[maxASindex]) && !ArrayGEvalue[lowASindex1])){
                        #print ArrayASvalue[1]," ", ArrayASvalue[2], " ", ArrayASvalue[3], " maxindex", maxASindex, " max2index", max2ASindex,\
			# "lowindex1", lowASindex1, "2max_oneCODING", ArrayGEvalue[maxASindex], ArrayGEvalue[max2ASindex]
			
			#if GE value for maxASindex exists, alter maxASindex:
			if (ArrayGEvalue[maxASindex]){
				ChangeSecondaryFlags(3, maxASindex, "XR:Z:Triple_2max_oneCODING")
			}
			
			#if no GE value for maxASindex, alter max2ASindex:
			 else if (!ArrayGEvalue[maxASindex]){
				ChangeSecondaryFlags(3, max2ASindex, "XR:Z:Triple_2max_oneCODING")
                        }

			for (i=3; i>=1; i--){
                                if(i==maxASindex){print ArrayLine[maxASindex]}
                                if(i==max2ASindex){print ArrayLine[max2ASindex]}
                                if(i==lowASindex1){print ArrayLine[lowASindex1]}
                        }
		}
		         
		else if (twomaxGEcount==1){
			#CHANGE MAX AS alignment  
                        #print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3], "\t maxindex","\t", maxASindex,\
			# "\t max2index","\t", max2ASindex, "\t lowindex1","\t", lowASindex1, "\t 2max_allortwoCODING", "\t", ArrayGEvalue[maxASindex]
        		if (ArrayGEvalue[maxASindex]) {
				ChangeSecondaryFlags(3, maxASindex, "XR:Z:Triple_2max_allortwoCODING_GEsame")
			} 

                        else if (!ArrayGEvalue[maxASindex]) {
				ChangeSecondaryFlags(3, max2ASindex, "XR:Z:Triple_2max_allortwoCODING_GEsame")

			}

                        for (i=3; i>=1; i--){
                                if(i==maxASindex){print ArrayLine[maxASindex]}
                                if(i==max2ASindex){print ArrayLine[max2ASindex]}
                                if(i==lowASindex1){print ArrayLine[lowASindex1]}
                        }
	        }
		else {
			#Conditions to include alignments are not satisfied, make sure all primary alignments are changed to secondary - otherwise primary alignments will be included in DGE.
			#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3],"\t","\t maxindex","\t", maxASindex,\
			# "\t max2index","\t", max2ASindex, "\t lowindex1","\t", lowASindex1, "\t 2max_conditionsNOTsatisfied"
			for (i=1; i<=3; i++){
                                n=split(ArrayLine[i], splitline)
                                nbinary=split(ArrayBinaryFlag[i], splitbinaryflag, "")
                                if (splitbinaryflag[3]==0){
                                        splitbinaryflag[3]=1
                                        ArrayBinaryFlag[i]=joinnospace(splitbinaryflag, nbinary)
                                        ArrayFlag[i]=Bin2Dec(ArrayBinaryFlag[i])
                                        splitline[2]=ArrayFlag[i]
                                        splitline[n+1]="XR:Z:Triple_2max_conditionsNOTsatisfied"
                                        ArrayLine[i]=join(splitline, n+1)
                                }
	                }

                        for (i=3; i>=1; i--){
                                if(i==maxASindex){print ArrayLine[maxASindex]}
                                if(i==max2ASindex){print ArrayLine[max2ASindex]}
                                if(i==lowASindex1){print ArrayLine[lowASindex1]}
                        }
                }
	}
}

#ASvalues the SAME 

#Do not need to use max/low indices - just 1,2,3
else if ((NR % 3 ==0 && XFflag==0) && (ArrayASvalue[1]==ArrayASvalue[2]) && (ArrayASvalue[1]==ArrayASvalue[3] )) {
	#For ONE alignment with GEvalue
	if ( myXOR( myXOR(ArrayGEvalue[1], ArrayGEvalue[2]), ArrayGEvalue[3]) && (((ArrayGEvalue[1] && ArrayGEvalue[2]) && ArrayGEvalue[3]) == 0 ) ) {
                        for(i=1; i<=3; i++){
				if (ArrayGEvalue[i]){
					indexCoding=i
				}
			}
			#CHANGE CODING alignment 
                        #print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3],"\t no_maxindex", "\t nomax_oneCODING","\t", ArrayGEvalue[indexCoding]
			
			ChangeSecondaryFlags(3, indexCoding, "XR:Z:Triple_NOmax_oneCODING")

                        for (i=3; i>=1; i--){
                                if(i==indexCoding){print ArrayLine[indexCoding]}
                                if(i!=indexCoding){print ArrayLine[i]}
                        }
       	}
	
	#If there are TWO coding alignments
	else if ( (((ArrayGEvalue[1] && ArrayGEvalue[2]) || ArrayGEvalue[3]) && (ArrayGEvalue[1]!=0 || ArrayGEvalue[2]!=0) ) && ((ArrayGEvalue[1] && ArrayGEvalue[2]) && ArrayGEvalue[3])==0 ) {
			for(i=1; i<=3; i++){
                                if ((ArrayGEvalue[i] && indexCoding1) && indexCoding1!=i){
					indexCoding2=i
				}
				if (ArrayGEvalue[i] && indexCoding2!=i){
                                        indexCoding1=i
                                }
				
                        }
			#If the GEvalues of the two coding alignments are the same:
			if (ArrayGEvalue[indexCoding1]==ArrayGEvalue[indexCoding2]){
                       		#CHANGE Coding alignment (indexCoding1) 
                        	#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3],"\t no_maxindex", "\t nomax_twoCODING_sameGE","\t", ArrayGEvalue[indexCoding1], "\t", ArrayGEvalue[indexCoding2]
                        	
				ChangeSecondaryFlags(3, indexCoding1, "XR:Z:Triple_NOmax_twoCODING_GEsame")
				
                        	for (i=3; i>=1; i--){
                                	if(i==indexCoding1){print ArrayLine[indexCoding1]}
                                	else if(i==indexCoding2){print ArrayLine[indexCoding2]}
					else { print ArrayLine[i]}
                        	}
			}
			else{
                                #print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3],"\t no_maxindex", "\t nomax_twoCODING_conditionsNOTsatisfied"
				for (i=1; i<=3; i++){
                               		n=split(ArrayLine[i], splitline)
                                	nbinary=split(ArrayBinaryFlag[i], splitbinaryflag, "")
                                	if (splitbinaryflag[3]==0){
                                        	splitbinaryflag[3]=1
                                        	ArrayBinaryFlag[i]=joinnospace(splitbinaryflag, nbinary)
                                        	ArrayFlag[i]=Bin2Dec(ArrayBinaryFlag[i])
                                        	splitline[2]=ArrayFlag[i]
                                        	splitline[n+1]="XR:Z:Triple_NOmax_twoCODING_conditionsNOTsatisfied"
                                        	ArrayLine[i]=join(splitline, n+1)
                                	}
	                	}

				for (i=3; i>=1; i--){
                                       if(i==indexCoding1){print ArrayLine[indexCoding1]}
                                       else if(i==indexCoding2){print ArrayLine[indexCoding2]}
                                       else { print ArrayLine[i]}
                                }
                        }
       }

	#If all 3 are coding alignments for same GE one of them will be pseudo-randomly assigned as primary, and the others as secondary. Indicate that included with XR tag for the primary read.

	else if ( ((ArrayGEvalue[1] && ArrayGEvalue[2]) && ArrayGEvalue[3]) && ((ArrayGEvalue[1]==ArrayGEvalue[2]) && (ArrayGEvalue[1]==ArrayGEvalue[3])) ) {
		#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3],"\t no_maxindex", "\t nomax_allCODING_sameGE","\t", ArrayGEvalue[1], "\t", ArrayGEvalue[2], "\t", ArrayGEvalue[3]
                        	#XRtag for primary read
				
				for (i=1; i<=3; i++){
                                	n=split(ArrayLine[i], splitline)
                                	nbinary=split(ArrayBinaryFlag[i], splitbinaryflag, "")
                                	if (splitbinaryflag[3]==0){
                                 	    splitline[n+1]="XR:Z:Triple_NOmax_allCODING_GEsame"
                                    	    ArrayLine[i]=join(splitline, n+1)
                                	}
                		}
	
                                print ArrayLine[3]
                        	print ArrayLine[2]
                        	print ArrayLine[1]
	}

	else {
	 		#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3],"\t no_maxindex", "\t nomax_conditionsNOTsatisfied","\t"
			for (i=1; i<=3; i++){
                                n=split(ArrayLine[i], splitline)
                                nbinary=split(ArrayBinaryFlag[i], splitbinaryflag, "")
                                if (splitbinaryflag[3]==0){
                                        splitbinaryflag[3]=1
                                        ArrayBinaryFlag[i]=joinnospace(splitbinaryflag, nbinary)
                                        ArrayFlag[i]=Bin2Dec(ArrayBinaryFlag[i])
                                        splitline[2]=ArrayFlag[i]
                                        splitline[n+1]="XR:Z:Triple_NOmax_conditionsNOTsatisfied"
                                        ArrayLine[i]=join(splitline, n+1)
                                }
                	}	
			print ArrayLine[3]
                        print ArrayLine[2]
                        print ArrayLine[1]
	}
}

#If are on last line of triplet, reset values to zero, ready for triplet set	
if (NR % 3 == 0){
	#delete ArrayASvalue
	#delete ArrayXFvalue
	#delete ArrayGEvalue
        #delete array is a gawk extension, need alternative solution:
        #ftp://ftp.gnu.org/old-gnu/Manuals/gawk-3.0.3/html_chapter/gawk_12.html
        split("", ArrayASvalue)
        split("", ArrayXFvalue)
        split("", ArrayGEvalue)
	split("", ArrayBinaryFlag)
	split("", ArrayFlag)
	split("", ArrayLine)
}

if ((NR+1) % 3 == 0){
	ArrayASvalue[2]=ASvalue
	ArrayXFvalue[2]=XFvalue
 	ArrayGEvalue[2]=GEvalue
	ArrayFlag[2]=$2
	ArrayBinaryFlag[2]=BinaryFlag
  	ArrayLine[2]=$0
}

if ((NR+2) % 3 == 0){
	ArrayASvalue[3]=ASvalue
	ArrayXFvalue[3]=XFvalue
	ArrayGEvalue[3]=GEvalue
	ArrayFlag[3]=$2
	ArrayBinaryFlag[3]=BinaryFlag
	ArrayLine[3]=$0
}

}
