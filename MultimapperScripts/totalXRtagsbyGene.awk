#Awk script to find total frequecies per gene of XR tags (gene sorted frequencies file)
#input: frequency GEtag XRtag
#output:frequency GEtag (for all XR tags)

BEGIN{
lastcount=0
}

{

if (NR==1){lastGene=$2}

#Compare genes
if ($2==lastGene){
	total=$1 + lastcount
	lastcount=total
	lastGene=$2
}

if ($2!=lastGene){       
	print total "\t" lastGene
	total=$1
	lastcount=$1
	lastGene=$2
}

}