# MIT License
# Copyright 2020 rcgsmith (Rosanna Smith)

#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
