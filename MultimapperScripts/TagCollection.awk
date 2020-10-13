#Awk script to collect GE tag and XR tag

BEGIN{
}

{
#Find XRtag:
XRexist=match($0,/XR:Z:[A-Za-z0-9\_]{0,100}/)
XRtag=substr($0, RSTART+5, RLENGTH-5) 
conditionsNOTsatisfied=match(XRtag, /conditionsNOTsatisfied$/)

if (XRexist && !conditionsNOTsatisfied){ 
		#Find GEtag:
		match($0,/GE:[A-Z]:[a-zA-Z0-9\^\.\*\(\)-]{1,50}/) 
		GEtag=substr($0, RSTART+5, RLENGTH-5)
	print GEtag "\t" XRtag
}

}
