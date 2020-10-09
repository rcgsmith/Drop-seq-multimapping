# Extension to Drop-seq bioinformatics pipeline (v1) to allow multimapping alignments in specific circumstances.

This set of scripts provides an extension to the Drop-seq bioinformatics pipeline v1 (http://mccarrolllab.org/dropseq/, https://github.com/broadinstitute/Drop-seq).

The extension allows exonic or UTR-aligned multimapping alignments with specific characteristics (detailed here) to be included in the input for creation of the digital gene expression matrix.


## Getting Started

Please read the following notes on the intended use and background of this altered pipeline before heading to Implementation. 

## Background

The standard Drop-seq (v1) pipeline uses the alignment output of the Star aligner (aligning reads to the genome). The Star aligner can output several possible alignment outputs for a single read (if they exist) and indicates the number of alignments for the read in the MAPQ column of the sam/bam alignment file. The possible Star MAPQ values are: 

*	255 -  one mapping location.
*	3 – two mapping locations.
*	1 – three or four mapping locations.
*	0 – five or more mapping locations.

The standard Drop-seq pipeline (v1) only uses unique alignments (ie. alignments with MAPQ=255). 

Only using unique alignments causes gene-specific issues when a read aligns to its actual source and also to other locations. Complete rejection of non-unique alignments is a source of gene-specific bias.

The challenge is to determine criteria for inclusion of alignments which can be considered to be the actual source of the read.  There are conditions in which it is reasonable to retain multimapping alignments depending on the characteristics of all the alignments in the set for a given read. 

In the context of polyA-enriched RNA-seq (as in Drop-seq), this extended pipeline allows a multimapping alignment to be included downstream if it is aligned to an exonic or UTR region and other alignments in the set are: 1) Intronic, intergenic or exonic for the same gene, and 2) have the same or worse alignment scores. Full details of inclusion criteria are below.

These criteria are based on the assumption that Drop-seq sequences predominantly mature mRNA which can be expected to align to exonic regions. However, this may not be the case, and if an intronic/intergenic alignment has a higher alignment score then an exonic alignment is not included from the same alignment set.

### Multimapping Alignment Inclusion Criteria

The Star aligner has the following output characteristics.

*	Reads have an alignment (AS) score from the aligner, which is the number of matching basepairs. 
*	The alignment that maps with the highest AS score is designated the ‘primary’ read.
*	All other alignments for the same read are ‘secondary’ reads.
*	If AS scores are the same, then the ‘primary’ read is designated pseudo-randomly (exactly how depends on version of Star aligner used).

Every alignment from the Star aligner is tagged in the Drop-Seq pipeline by XC and XM tags (cell and molecular barcodes), 	an XF tag (CODING, UTR, INTRONIC, INTERGENIC) and GE tag (name of gene), if it aligns to a single gene exon in the correct orientation. 

This extension of the Drop-seq bioinformatics pipeline compares the alignments within each multimapping alignment set. It allows alignments according to the criteria summarised below, and set out in detail in the logic tables beneath:
 
*	Alignments are allowed if they are exonic, have the maximum/co-maximum alignment score from the set of alignments, AND, the other alignments (with lower/equal alignment scores) are intronic/intergenic/exonic for the same gene. 

*	No alignments are included from sets that contain mappings to different genes (as given by the GE tag). 

*	Sets of alignments containing more than one alignment to the same gene are allowed (if the maximum/co-maximum AS score alignment is exonic and there are no alignments to different genes). This means that a read with mappings to multiple regions on the same gene will be include in the digital gene expression output. This criterion particularly affects genes with repeat units.

PLEASE NOTE: The same-gene criterion is suitable for digital gene expression analysis, where we are concerned with overall mRNA counts from a gene. However, the altered bam files from this pipeline should not be used in analyses for which the specific mRNA variants are important (and the analysis includes multimapping alignments). This is because the ‘primary’/ ’secondary’ flag alterations may introduce variant specific bias.

The DigitalExpression Drop-Seq tool only includes ‘primary’ alignments. When the multimapping criteria above are met then the set of alignments is altered so that the allowed alignment is flagged as ‘primary’ and the other alignments are flagged as ‘secondary’.  If the criteria are not met, then all alignments are flagged as ‘secondary’. In this way we indicate the allowed multimappers with the ‘primary’ flag and they are counted by the DigitalExpression tool. As there is only one primary-flagged alignment per set, only one alignment per set can be included. 

There is also a specifiable MAPQ (READMQ) threshold for inclusion in the digitial gene expression output. This is set to 1 in order to allow ‘primary’ dual, triple and quadruple alignments. The standard drop-seq pipeline uses READMQ=10, which only allows unique mappers (which are all ‘primary’ alignments).

### Inclusion criteria logic tables for Dual, Triple and Quadruple multimapping alignments.

XF tag determines whether an alignment is Coding or Non-coding:

*	Coding if CODING/UTR 
*	Non-coding if INTRONIC/INTERGENIC. 

If any of the XF read tags for a set of alignments is CODING/UTR but without a GE tag, then that set of mappers (dual, triple, quadruple) is not considered (all alignments set to ‘secondary’)
       Indicates alignment to be altered, (if condition is met).
       
Dual mappers:

<img src="/Images/Dual_Mappers_Image.png" width="70%">

Triple mappers

<img src="/Images/Triple_Mappers_Image.png" width="75%">

Quadruple mappers

<img src="/Images/Quad_Mappers_Image.png" width="80%">


### Implementation
This set of scripts is designed to be incorporated into the user’s current Drop-seq pipeline (v1) setup. Extended pipeline output includes all standard Drop-seq output as well as equivalent files with inclusion of specific multimapping alignments as outlined above. 

The following description makes use of the same file descriptions and nomenclature as in Drop-seq computational protocol v1.2 (http://mccarrolllab.org/wp-content/uploads/2016/03/Drop-seqAlignmentCookbookv1.2Jan2016.pdf), and the Drop-seq tools v1.13. Both available at https://github.com/broadinstitute/Drop-seq/releases/tag/v1.13.

The comparison of multimapping alignment sets requires the samtools package (http://www.htslib.org/) and bash and awk implementations. It has been tested on systems implementing:
•	samtools v1.3.2,  
•	awk version 20070501 (macOS) and gawk (GNU awk 3.1.7) 
•	GNU bash versions 3.2.57(1)-release (x86_64-apple-darwin17) and 4.1.2(1)-release (x86_64-redhat-linux-gnu).

In User’s own Drop-seq pipeline:

1)	Create mm_out_dir variable for Drop-seq pipeline output path. This mm_out_dir variable is required by the extended pipeline, even if path is already specified by another variable.
mm_out_dir=own/output/path
2)	Create temporary directory in own/output/path:
mkdir $mm_out_dir/temp
3)	Copy MultimapperScripts folder available here to a pipeline-accessible folder at own/path/to/MultimapperScripts
4)	Create variable for MultimapperScripts path:
multifolder=own/path/to/MultimapperScripts
5)	Make a copy of own implementation of Drop-seq_alignment.sh, rename it as Drop-seq_alignment_incMultimappers.sh and place in own/path/to/MultimapperScripts.
6)	In Drop-seq_alignment_incMultimappers.sh, change the merge_bam command so that multimapping alignments are included downstream (ie change to INCLUDE_SECONDARY_ALIGNMENTS=true)

# Stage 4: merge and tag aligned reads
merge_bam="java -Xmx4000m -jar ${picard_jar} MergeBamAlignment REFERENCE_SEQUENCE=${reference} UNMAPPED_BAM=${tagged_unmapped_bam} \
ALIGNED_BAM=${aligned_sorted_bam} INCLUDE_SECONDARY_ALIGNMENTS=true PAIRED_RUN=true"
tag_with_gene_exon="${dropseq_root}/TagReadWithGeneExon O=${tmpdir}/star_gene_exon_tagged.bam ANNOTATIONS_FILE=${refflat} TAG=GE"

7)	Where Drop-seq_alignment.sh is invoked, instead invoke $multifolder/Drop-seq_alignment_incMultimappers.sh (with same options as for Drop-seq_alignment.sh).
8)	Extend standard pipeline with three new sections at the end:

A.	Compare Multimapping Alignment Sets 

alteration_input=$mm_out_dir/clean_star_gene_exon_tagged.bam
outputfile=$mm_out_dir/multimap_altered_clean_star_gene_exon_tagged.bam

source $multifolder/MultimapperAlteration.sh 

B.	Digital Gene Expression including multimapping alignments meeting inclusion criteria  - use same parameters as for standard pipeline DGE except that need READ_MQ=1.

DigitalExpression 
I=$mm_out_dir/multimap_altered_clean_star_gene_exon_tagged.bam 
O=$mm_out_dir/multimap_altered_out_gene_exon_tagged.dge.txt.gz 
SUMMARY=$mm_out_dir/multimap_altered_out_gene_exon_tagged.dge.summary.txt 
READ_MQ=1 

C.	BamTag Histogram for Digital Gene Expression including multimapping alignments meeting inclusion criteria

BAMTagHistogram 
I=$mm_out_dir/multimap_altered_clean_star_gene_exon_tagged.bam 
O=$mm_out_dir/multimap_altered_out_cell_readcounts.txt.gz 
TAG=XC 
READ_QUALITY=1 

Alteration metrics  
The extended pipeline outputs metrics on the multimapping alignments meeting inclusion requirements. An XR tag is added to each primary-flagged alignment in a set, either included multimapping alignment describing its type:

XR:Z:Dual/Triple/Quad_No.max.AS.scores_No.CODING.max.AS.scores_is.GE.same

XR and GE tags for included multimappers are gathered in the following metrics files:

XRtags_totals.txt - Frequencies of all multimappers over all genes.
GEtags_XRtotals.txt - Frequencies of all multimappers for each gene.
GEtags_XRfrequencies.txt - Frequencies of each type of multimapper (each XR tag type) for each gene.

### Workflow for comparing multimapping alignment sets - MultimapperAlteration.sh:
