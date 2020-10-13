# MIT License
# Copyright 2020 rcgsmith (Rosanna Smith)

#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#Script to alter quadruple alignments
BEGIN{ 

}

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

#testing conversions:
#if (NR == 1){
#	for (i=0; i<=50; i++){
#		j=Dec2Bin(i)
#		print i "\t" j "\t" Bin2Dec(j)
#	}
#}

if (NR % 4 ==0){
	ArrayASvalue[1]=ASvalue
	ArrayXFvalue[1]=XFvalue
	ArrayGEvalue[1]=GEvalue
	ArrayFlag[1]=$2
	ArrayBinaryFlag[1]=BinaryFlag
	ArrayLine[1]=$0
	XFflag=0
        for (i=1; i<=4; i++){
                if ((ArrayXFvalue[i]=="CODING" || ArrayXFvalue[i]=="UTR") && !ArrayGEvalue[i]){XFflag=1}
        }
}

 
if (NR % 4 == 0  && XFflag==1){
	#Need to make sure all alignments have secondary flag:
        for (i=1; i<=4; i++){
                n=split(ArrayLine[i], splitline)
                nbinary=split(ArrayBinaryFlag[i], splitbinaryflag, "")
                if (splitbinaryflag[3]==0){
                        splitbinaryflag[3]=1
                        ArrayBinaryFlag[i]=joinnospace(splitbinaryflag, nbinary)
                        ArrayFlag[i]=Bin2Dec(ArrayBinaryFlag[i])
                        splitline[2]=ArrayFlag[i]
                        splitline[n+1]="XR:Z:Quad_XFnoGE_conditionsNOTsatisfied"
                        ArrayLine[i]=join(splitline, n+1)
                }
        }

        print ArrayLine[4]
	print ArrayLine[3]
        print ArrayLine[2]
        print ArrayLine[1]
}

#Work with quadruplets of lines, therefore assess every 4th line. If on other lines, simply store previous lines and store values in array
	maxASvalue=""
        max2ASvalue=""
        max3ASvalue=""
        maxASindex=""
        max2ASindex=""
        max3ASindex=""
        lowASindex1=""
        lowASindex2=""
        lowASindex3=""
	indexCoding=""
	indexCoding1=""
	indexCoding2=""
	indexCoding3=""
	indexchange=""
	ASsameGEcount=0
	ASdiffGEcount=0

#ASvalue DIFFERENT - there is at least one lastASvalue which is not the same as this ASvalue
if ( (NR % 4 ==0 && XFflag==0) && !((ArrayASvalue[1]==ArrayASvalue[2] && ArrayASvalue[1]==ArrayASvalue[3]) && ArrayASvalue[1]==ArrayASvalue[4]) ){
	#create indices for AS values:
      	#ASvalue with index for maximum ASvalue
	for (i=1; i<=4; i++){
		if (maxASvalue < ArrayASvalue[i]) {
			maxASvalue=ArrayASvalue[i] 
			maxASindex=i			
		}	
	}

	#Is there another with same max AS value?		
	for (j=1; j<=4; j++){
		if (((maxASvalue == ArrayASvalue[j]) && (j != maxASindex)) &&  !max2ASindex){
			max2ASindex=j
                }
		else if (((maxASvalue == ArrayASvalue[j]) && max2ASindex) && (j != max2ASindex && !max3ASindex)){
			max3ASindex=j
                }
		#print "maxindex ", maxASindex, "max2index ", max2ASindex, "max3index ", max3ASindex  
	}

	#Define indices for non-maxAS values when only 1 max value
	if (!max2ASindex){
		if (maxASindex==1){
			lowASindex1=2
			lowASindex2=3
			lowASindex3=4
		}
		else if (maxASindex==2){
         	      	lowASindex1=1
                	lowASindex2=3
			lowASindex3=4
        	}
		else if (maxASindex==3){
                	lowASindex1=1
                	lowASindex2=2
			lowASindex3=4
        	}
		else if (maxASindex==4){
                	lowASindex1=1
                	lowASindex2=2
			lowASindex3=3
        	}
	}
	#Define indices for non-maxAS values when two max values (max and max2, no max3)
	else if (max2ASindex && !max3ASindex){
		if (maxASindex==1){
			if(max2ASindex==2){
				lowASindex1=3
				lowASindex2=4
			}
			else if(max2ASindex==3){
				lowASindex1=2
				lowASindex2=4
			}
			else if(max2ASindex==4){
				lowASindex1=2
				lowASindex2=3
			}
		}
		else if (maxASindex==2){
			if(max2ASindex==3){
				lowASindex1=1
				lowASindex2=4
			}
			else if(max2ASindex==4){
				lowASindex1=1
				lowASindex2=3
			}
		}
		else if (maxASindex==3){
			if(max2ASindex==4){
				lowASindex1=1
				lowASindex2=2
			}
		}
	}

	#Define indices for non-maxAS values when 3 max values
	else if (max3ASindex){
		if ((maxASindex==1 && max2ASindex==2) && max3ASindex==3){
			lowASindex1=4
		}
		else if ((maxASindex==1 && max2ASindex==2) && max3ASindex==4){
			lowASindex1=3
		}
		else if ((maxASindex==1 && max2ASindex==3) && max3ASindex==4){
			lowASindex1=2
		}
		else if ((maxASindex==2 && max2ASindex==3) && max3ASindex==4){
			lowASindex1=1
		}
	}

	#Count the number of coding maxes:
		if (ArrayGEvalue[maxASindex]) {ASdiffGEcount++}
		if (ArrayGEvalue[max2ASindex]) {ASdiffGEcount++}
		if (ArrayGEvalue[max3ASindex]) {ASdiffGEcount++}
	

	#When have ONE maxASvalue:

	if  (!max2ASindex){
		#If GEvalue exists it means that alignment must be CODING/UTR, if not, then is INTERGENIC/INTRONIC or is on wrong strand of coding region
                
		#max AS value alignment is coding and others are not:
		if ( ArrayGEvalue[maxASindex] && !ArrayGEvalue[lowASindex1] && !ArrayGEvalue[lowASindex2] && !ArrayGEvalue[lowASindex3]){
                        #CHANGE MAX AS alignment 
			#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3], "\t", ArrayASvalue[4], "\t maxindex","\t", maxASindex,\
			# "\t lowindex1","\t", lowASindex1, "\t lowindex2", "\t",lowASindex2, "\t lowindex3", "\t", lowASindex3, "\t 1max_oneCODING","\t", ArrayGEvalue[maxASindex]
			
			ChangeSecondaryFlags(4, maxASindex, "XR:Z:Quad_1max_ONLYmaxCODING")

			for (i=4; i>=1; i--){
				if(i==maxASindex){print ArrayLine[maxASindex]}
                        	if(i==lowASindex1){print ArrayLine[lowASindex1]}
                        	if(i==lowASindex2){print ArrayLine[lowASindex2]}
				if(i==lowASindex3){print ArrayLine[lowASindex3]}
			}   
			#print "" 
		}

		#all alignments are coding, with same GEvalue ie. max GE value exists and equals others
		#or one max GEvalue and one of low GEvalues are the same, with the other being noncoding.
		
		else if (ArrayGEvalue[maxASindex] && (((ArrayGEvalue[lowASindex1] && (ArrayGEvalue[lowASindex1]== ArrayGEvalue[maxASindex]))\
						|| (ArrayGEvalue[lowASindex2] && (ArrayGEvalue[lowASindex2]== ArrayGEvalue[maxASindex])))\
						|| (ArrayGEvalue[lowASindex3] && (ArrayGEvalue[lowASindex3]== ArrayGEvalue[maxASindex])))) {
			#CHANGE MAX AS alignment
			#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3], "\t", ArrayASvalue[4], "\t", ArrayASvalue[4], "\t maxindex", "\t", maxASindex,\
			# "\t lowindex1","\t", lowASindex1, "\t lowindex2", "\t", lowASindex2, "\t lowindex3", "\t", lowASindex3, "\t 1max_allortwoCODING", "\t", ArrayGEvalue[maxASindex]
			ChangeSecondaryFlags(4, maxASindex, "XR:Z:Quad_1max_morethanoneCODING_GEsame")

			for (i=4; i>=1; i--){
				if(i==maxASindex){print ArrayLine[maxASindex]}
                        	if(i==lowASindex1){print ArrayLine[lowASindex1]}
                        	if(i==lowASindex2){print ArrayLine[lowASindex2]}
				if(i==lowASindex3){print ArrayLine[lowASindex3]}
			}   
			#print "" 
		}
		else {
                        #Conditions to include alignments are not satisfied, make sure all primary alignments are changed to secondary - otherwise primary alignments will be included in DGE.
			#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3], "\t", ArrayASvalue[4], " maxindex", maxASindex,\
			#”lowindex1", lowASindex1, "lowindex2", lowASindex2, "lowindex3", lowASindex3, "1max_conditionsNOTsatisfied"
			for (i=1; i<=4; i++){
                                n=split(ArrayLine[i], splitline)
                                nbinary=split(ArrayBinaryFlag[i], splitbinaryflag, "")
                                if (splitbinaryflag[3]==0){
                                        splitbinaryflag[3]=1
                                        ArrayBinaryFlag[i]=joinnospace(splitbinaryflag, nbinary)
                                        ArrayFlag[i]=Bin2Dec(ArrayBinaryFlag[i])
                                        splitline[2]=ArrayFlag[i]
                                        splitline[n+1]="XR:Z:Quad_1max_conditionsNOTsatisfied"
                                        ArrayLine[i]=join(splitline, n+1)
                                }
                	}

                      	for (i=4; i>=1; i--){
				if(i==maxASindex){print ArrayLine[maxASindex]}
                        	if(i==lowASindex1){print ArrayLine[lowASindex1]}
                        	if(i==lowASindex2){print ArrayLine[lowASindex2]}
				if(i==lowASindex3){print ArrayLine[lowASindex3]}
			}   
			#print "" 
                }
	}	

	
	#When have TWO maxASvalues:
	else if  (max2ASindex && !max3ASindex){
		#max and max2 index criteria: One or both coding and if both coding, same GEvalue
		condition1= myXOR(ArrayGEvalue[maxASindex], ArrayGEvalue[max2ASindex]) || ((ArrayGEvalue[maxASindex] && ArrayGEvalue[max2ASindex])\
				 && (ArrayGEvalue[maxASindex]==ArrayGEvalue[max2ASindex]))
		
		#lowindex1 and lowindex2 do not exist ie. non coding
		condition2= !ArrayGEvalue[lowASindex1] && !ArrayGEvalue[lowASindex2]
		
		#one or both of lowindex1 and lowindex2 exist and is/are the same GEvalue as maxindex/max2index.
		condition3= (ArrayGEvalue[lowASindex1] && ((ArrayGEvalue[maxASindex] == ArrayGEvalue[lowASindex1]) || (ArrayGEvalue[max2ASindex] == ArrayGEvalue[lowASindex1]) )\
				|| (ArrayGEvalue[lowASindex2] && ((ArrayGEvalue[maxASindex] == ArrayGEvalue[lowASindex2]) || (ArrayGEvalue[max2ASindex] == ArrayGEvalue[lowASindex2]))) )
		
		if (condition1 && (condition2 || condition3) ){
                        #print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3],"\t", ArrayASvalue[4] " maxindex", maxASindex, " max2index", max2ASindex,\
			#”lowindex1", lowASindex1, "lowindex2", lowASindex2, "2max_oneormoreCODING", ArrayGEvalue[maxASindex], ArrayGEvalue[max2ASindex]
			
			#Change coding maxASindex/max2
			if (!ArrayGEvalue[maxASindex])
				{indexchange= max2ASindex}
			else if (ArrayGEvalue[maxASindex] && myXOR((ArrayGEvalue[maxASindex]==ArrayGEvalue[max2ASindex]),!ArrayGEvalue[max2ASindex]))  
				{indexchange= maxASindex}
			
			ChangeSecondaryFlags(4, indexchange, "XR:Z:Quad_2max_oneormoreCODING_GEsame")
			
			for (i=4; i>=1; i--){
                                if(i==maxASindex){print ArrayLine[maxASindex]}
				if(i==max2ASindex){print ArrayLine[max2ASindex]}
                                if(i==lowASindex1){print ArrayLine[lowASindex1]}
				if(i==lowASindex2){print ArrayLine[lowASindex2]}
                        }
			#print "" 
		}
		else {
			#Conditions to include alignments are not satisfied, make sure all primary alignments are changed to secondary - otherwise primary alignments will be included in DGE.
			#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3], "\t", ArrayASvalue[4], " maxindex", maxASindex, " max2index", max2ASindex,\
			#”lowindex1", lowASindex1, "lowindex2", lowASindex2, "\t 2max_conditionsNOTsatisfied"
			for (i=1; i<=4; i++){
                                n=split(ArrayLine[i], splitline)
                                nbinary=split(ArrayBinaryFlag[i], splitbinaryflag, "")
                                if (splitbinaryflag[3]==0){
                                        splitbinaryflag[3]=1
                                        ArrayBinaryFlag[i]=joinnospace(splitbinaryflag, nbinary)
                                        ArrayFlag[i]=Bin2Dec(ArrayBinaryFlag[i])
                                        splitline[2]=ArrayFlag[i]
                                        splitline[n+1]="XR:Z:Quad_2max_conditionsNOTsatisfied"
                                        ArrayLine[i]=join(splitline, n+1)
                                }
                        }                        

			for (i=4; i>=1; i--){
                                if(i==maxASindex){print ArrayLine[maxASindex]}
				if(i==max2ASindex){print ArrayLine[max2ASindex]}
                                if(i==lowASindex1){print ArrayLine[lowASindex1]}
				if(i==lowASindex2){print ArrayLine[lowASindex2]}
                        }  
			#print ""               
		}
	}

	#When have THREE maxASvalues:
	else if (max3ASindex){ 
		#ONE of max/max2/max3 is coding 
		if ( ASdiffGEcount==1 ){
			if (ArrayGEvalue[maxASindex]){indexchange= maxASindex}
			else if (ArrayGEvalue[max2ASindex]){indexchange= max2ASindex}	
			else if (ArrayGEvalue[max3ASindex]){indexchange= max3ASindex}
			label="XR:Z:Quad_3max_onemaxCODING"
		}

		#TWO of max/max2/max3 are coding:
		else if (ASdiffGEcount==2){
			if ((ArrayGEvalue[maxASindex] && ArrayGEvalue[max2ASindex]) && (ArrayGEvalue[maxASindex]==ArrayGEvalue[max2ASindex])){indexchange= maxASindex}
			else if ((ArrayGEvalue[maxASindex] && ArrayGEvalue[max3ASindex]) && (ArrayGEvalue[maxASindex]==ArrayGEvalue[max3ASindex])){indexchange= maxASindex}	
			else if ((ArrayGEvalue[max2ASindex] && ArrayGEvalue[max3ASindex]) && (ArrayGEvalue[max2ASindex]==ArrayGEvalue[max3Asindex])){indexchange= max2ASindex}
			label="XR:Z:Quad_3max_twomaxCODING_GEsame"
		}

		#all THREE of max/max2/max3 are coding:
		else if (ASdiffGEcount==3 && ((ArrayGEvalue[maxASindex]==ArrayGEvalue[max2ASindex]) && (ArrayGEvalue[maxASindex]==ArrayGEvalue[max3ASindex])) ){
			indexchange= maxASindex
			label="XR:Z:Quad_3max_threemaxCODING_GEsame"
		}

		#If lowASindex1 GEvalue exists, then must be the same as indexchange GEvalue
		if ( indexchange && ((ArrayGEvalue[lowASindex1] && (ArrayGEvalue[lowASindex1]==ArrayGEvalue[indexchange])) || !ArrayGEvalue[lowASindex1])) {
			#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3],"\t", ArrayASvalue[4] " maxindex", maxASindex, " max2index", max2ASindex,\
			#”max3index", max3ASindex, "lowindex1", lowASindex1, "3max_one2threeCODING", ArrayGEvalue[maxASindex], ArrayGEvalue[max2ASindex], ArrayGEvalue[max3ASindex]
			
			#Change the indexchange line 
				
			ChangeSecondaryFlags(4, indexchange, label)

			for (i=4; i>=1; i--){
                                if(i==maxASindex){print ArrayLine[maxASindex]}
				if(i==max2ASindex){print ArrayLine[max2ASindex]}
                                if(i==max3ASindex){print ArrayLine[max3ASindex]}
				if(i==lowASindex1){print ArrayLine[lowASindex1]}
                        }
			#print "" 
		}
		else {
			#Conditions to include alignments are not satisfied, make sure all primary alignments are changed to secondary - otherwise primary alignments will be included in DGE.
			#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3],"\t", ArrayASvalue[4] " maxindex", maxASindex, " max2index", max2ASindex,\
                        #”max3index", max3ASindex, "lowindex1", lowASindex1, "3max_CODING", "conditionsNOTsatisfied"
			for (i=1; i<=4; i++){
                                n=split(ArrayLine[i], splitline)
                                nbinary=split(ArrayBinaryFlag[i], splitbinaryflag, "")
                                if (splitbinaryflag[3]==0){
                                        splitbinaryflag[3]=1
                                        ArrayBinaryFlag[i]=joinnospace(splitbinaryflag, nbinary)
                                        ArrayFlag[i]=Bin2Dec(ArrayBinaryFlag[i])
                                        splitline[2]=ArrayFlag[i]
                                        splitline[n+1]="XR:Z:Quad_3max_conditionsNOTsatisfied"
                                        ArrayLine[i]=join(splitline, n+1)
                                }
                	}			

			for (i=4; i>=1; i--){
                                if(i==maxASindex){print ArrayLine[maxASindex]}
                                if(i==max2ASindex){print ArrayLine[max2ASindex]}
                                if(i==max3ASindex){print ArrayLine[max3ASindex]}
                                if(i==lowASindex1){print ArrayLine[lowASindex1]}
                        }
                        #print ""
		}
	}
}

#ASvalues the SAME 

#Do not need to use max/low indices - just 1,2,3,4
else if ((NR % 4 == 0 && XFflag==0) && (((ArrayASvalue[1]==ArrayASvalue[2]) && (ArrayASvalue[1]==ArrayASvalue[3])) && (ArrayASvalue[1]==ArrayASvalue[4]))){
	ASsameGEcount=0
	for (k=1; k<=4; k++){
		if (ArrayGEvalue[k]){ASsameGEcount++}		
	}
	#For NO alignments with GEvalue:

	if (ASsameGEcount==0) {
                       # print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3], "\t", ArrayASvalue[4], "\t no_maxindex", "\t nomax_noneCODING","\t"
                        for (i=1; i<=4; i++){
                                n=split(ArrayLine[i], splitline)
                                nbinary=split(ArrayBinaryFlag[i], splitbinaryflag, "")
                                if (splitbinaryflag[3]==0){
                                        splitbinaryflag[3]=1
                                        ArrayBinaryFlag[i]=joinnospace(splitbinaryflag, nbinary)
                                        ArrayFlag[i]=Bin2Dec(ArrayBinaryFlag[i])
                                        splitline[2]=ArrayFlag[i]
                                        splitline[n+1]="XR:Z:Quad_NOmax_conditionsNOTsatisfied"
                                        ArrayLine[i]=join(splitline, n+1)
                                }
                	}

			print ArrayLine[4]
                        print ArrayLine[3]
                        print ArrayLine[2]
                        print ArrayLine[1]
                       # print ""
       	}

	#For ONE alignment with GEvalue
	else if( ASsameGEcount==1 ) {
                        for(i=1; i<=4; i++){
				if (ArrayGEvalue[i]){
					indexCoding=i
				}
			}
			#CHANGE CODING alignment 
                        if (indexCoding) {
				#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3], "\t", ArrayASvalue[4],\
				#	 "\t no_maxindex", "\t nomax_oneCODING","\t", ArrayGEvalue[indexCoding]
                        	ChangeSecondaryFlags(4, indexCoding, "XR:Z:Quad_NOmax_oneCODING")

                        	for (i=4; i>=1; i--){
                                	if(i==indexCoding){print ArrayLine[indexCoding]}
                        	      	if(i!=indexCoding){print ArrayLine[i]}
                       		}
				#print "" 
			}
       	}
	
	#If there are TWO coding alignments
	else if ( ASsameGEcount==2)  {
			for(i=1; i<=4; i++){
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
                     	   	#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3],"\t", ArrayASvalue[4], "\t no_maxindex", "\t nomax_twoCODING_sameGE","\t",\
				# ArrayGEvalue[indexCoding1], "\t", ArrayGEvalue[indexCoding2]
                        	ChangeSecondaryFlags(4, indexCoding1, "XR:Z:Quad_NOmax_twoCODING_GEsame")

                        	for (i=4; i>=1; i--){
                                	if(i==indexCoding1){print ArrayLine[indexCoding1]}
                                	else if(i==indexCoding2){print ArrayLine[indexCoding2]}
					else { print ArrayLine[i]}
                        	}
				#print "" 
			}
			else{
                        	#Conditions to include alignments are not satisfied, make sure all primary alignments are changed to secondary - otherwise primary alignments will be included in DGE.
			        #print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3],"\t", ArrayASvalue[4], "\t no_maxindex", "\t nomax_twoCODING_conditionsNOTsatisfied"
				for (i=1; i<=4; i++){
                                	n=split(ArrayLine[i], splitline)
                                	nbinary=split(ArrayBinaryFlag[i], splitbinaryflag, "")
                                	if (splitbinaryflag[3]==0){
                                        	splitbinaryflag[3]=1
                                        	ArrayBinaryFlag[i]=joinnospace(splitbinaryflag, nbinary)
                                        	ArrayFlag[i]=Bin2Dec(ArrayBinaryFlag[i])
                                        	splitline[2]=ArrayFlag[i]
                                        	splitline[n+1]="XR:Z:Quad_NOmax_conditionsNOTsatisfied"
                                	        ArrayLine[i]=join(splitline, n+1)
                        	        }
                		}

				for (i=4; i>=1; i--){
                                       if(i==indexCoding1){print ArrayLine[indexCoding1]}
                                       else if(i==indexCoding2){print ArrayLine[indexCoding2]}
                                       else { print ArrayLine[i]}
                                }
				#print "" 
                        }
       }

	#If there are THREE coding alignments for same GE:
	else if ( ASsameGEcount==3 ) {

			for(i=1; i<=4; i++){
				if ((ArrayGEvalue[i] && indexCoding2) && (indexCoding2!=i && !indexCoding3) ){
					indexCoding3=i
				}
                                if ((ArrayGEvalue[i] && indexCoding1) && (indexCoding1!=i && indexCoding3!=i )){
					indexCoding2=i
				}
				if ((ArrayGEvalue[i] && !indexCoding2) && indexCoding2!=i){
                                        indexCoding1=i
                                }
				# print "indexCoding1 ", indexCoding1, "indexCoding2 ", indexCoding2,"indexCoding3 ", indexCoding3		
                        }
			#If the GEvalues of the three coding alignments are the same:
			if (ArrayGEvalue[indexCoding1]==ArrayGEvalue[indexCoding2] && ArrayGEvalue[indexCoding1]== ArrayGEvalue[indexCoding3]){
                       		#CHANGE Coding alignment (indexCoding1) 
                        	#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3],"\t", ArrayASvalue[4],\
				#”\t no_maxindex", "\t nomax_threeCODING_sameGE","\t", ArrayGEvalue[indexCoding1], "\t", ArrayGEvalue[indexCoding2], "\t", ArrayGEvalue[indexCoding3]
				ChangeSecondaryFlags(4, indexCoding1, "XR:Z:Quad_NOmax_threeCODING_GEsame")                        	

                        	for (i=4; i>=1; i--){
                                	if(i==indexCoding1){print ArrayLine[indexCoding1]}
                                	else if(i==indexCoding2){print ArrayLine[indexCoding2]}
					else if(i==indexCoding3){print ArrayLine[indexCoding3]}
					else { print ArrayLine[i]}
                        	}
				#print "" 
			}
			else{
				#Conditions to include alignments are not satisfied, make sure all primary alignments are changed to secondary - otherwise primary alignments will be included in DGE.
                                #print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3],"\t", ArrayASvalue[4], "\t no_maxindex", "\t nomax_threeCODING_conditionsNOTsatisfied"
				for (i=1; i<=4; i++){
                               		 n=split(ArrayLine[i], splitline)
                               		 nbinary=split(ArrayBinaryFlag[i], splitbinaryflag, "")
                               		 if (splitbinaryflag[3]==0){
                                	        splitbinaryflag[3]=1
                                	        ArrayBinaryFlag[i]=joinnospace(splitbinaryflag, nbinary)
                                	        ArrayFlag[i]=Bin2Dec(ArrayBinaryFlag[i])
                                	        splitline[2]=ArrayFlag[i]
                                	        splitline[n+1]="XR:Z:Quad_NOmax_conditionsNOTsatisfied"
                                	        ArrayLine[i]=join(splitline, n+1)
                        	        }
                		}

				for (i=4; i>=1; i--){
                                       	if(i==indexCoding1){print ArrayLine[indexCoding1]}
                                       	else if(i==indexCoding2){print ArrayLine[indexCoding2]}
					else if(i==indexCoding3){print ArrayLine[indexCoding3]}
                                       	else { print ArrayLine[i]}
                                }
				#print "" 
                        }
      	}

	#IF all FOUR coding for same GE:
	else if ( ASsameGEcount==4 ) {
		if( ((ArrayGEvalue[1]==ArrayGEvalue[2] && ArrayGEvalue[1]==ArrayGEvalue[3]) && (ArrayGEvalue[1]==ArrayGEvalue[4])) ){
		#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3], "\t", ArrayASvalue[4], "\t no_maxindex",\
		# "\t nomax_fourCODING_sameGE","\t", ArrayGEvalue[1], "\t", ArrayGEvalue[2], "\t", ArrayGEvalue[3], "\t", ArrayGEvalue[4]
				for (i=1; i<=4; i++){
                                	n=split(ArrayLine[i], splitline)
                                	nbinary=split(ArrayBinaryFlag[i], splitbinaryflag, "")
                                	if (splitbinaryflag[3]==0){
                                     		#Do not alter splitbinaryflag, just addd XR tag
                                	        splitline[n+1]="XR:Z:Quad_NOmax_fourCODING_GEsame"
                        	                ArrayLine[i]=join(splitline, n+1)
                	                }
        	        	}

				print ArrayLine[4]
                                print ArrayLine[3]
                        	print ArrayLine[2]
                        	print ArrayLine[1]
				#print "" 
		}
		else {
	 		#Conditions to include alignments are not satisfied, make sure all primary alignments are changed to secondary - otherwise primary alignments will be included in DGE.
			#print ArrayASvalue[1],"\t", ArrayASvalue[2], "\t", ArrayASvalue[3], "\t", ArrayASvalue[4], "\t no_maxindex", "\t nomax_fourCODING_conditionsNOTsatisfied","\t"
			for (i=1; i<=4; i++){
                                n=split(ArrayLine[i], splitline)
                                nbinary=split(ArrayBinaryFlag[i], splitbinaryflag, "")
                                if (splitbinaryflag[3]==0){
                                        splitbinaryflag[3]=1
                                        ArrayBinaryFlag[i]=joinnospace(splitbinaryflag, nbinary)
                                        ArrayFlag[i]=Bin2Dec(ArrayBinaryFlag[i])
                                        splitline[2]=ArrayFlag[i]
                                        splitline[n+1]="XR:Z:Quad_NOmax_conditionsNOTsatisfied"
                                        ArrayLine[i]=join(splitline, n+1)
                                }
                	}

			print ArrayLine[4]
			print ArrayLine[3]
                        print ArrayLine[2]
                        print ArrayLine[1]
			#print "" 
		}
	}
}

#If are on last line of quadruplet, reset values to zero, ready for triplet set	
if (NR % 4 == 0){
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

if ((NR+1) % 4 == 0){
	ArrayASvalue[2]=ASvalue
	ArrayXFvalue[2]=XFvalue
 	ArrayGEvalue[2]=GEvalue
	ArrayFlag[2]=$2
	ArrayBinaryFlag[2]=BinaryFlag
  	ArrayLine[2]=$0
}

if ((NR+2) % 4 == 0){
	ArrayASvalue[3]=ASvalue
	ArrayXFvalue[3]=XFvalue
	ArrayGEvalue[3]=GEvalue
	ArrayFlag[3]=$2
	ArrayBinaryFlag[3]=BinaryFlag
	ArrayLine[3]=$0
}

if ((NR+3) % 4 == 0){
	ArrayASvalue[4]=ASvalue
	ArrayXFvalue[4]=XFvalue
	ArrayGEvalue[4]=GEvalue
	ArrayFlag[4]=$2
	ArrayBinaryFlag[4]=BinaryFlag
	ArrayLine[4]=$0
}

}
