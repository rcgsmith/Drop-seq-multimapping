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

![Dual_Mappers_Image](/Images/Dual_Mappers_Image.png)

### Prerequisites

What things you need to install the software and how to install them
