# Genome Variant Pipeline (learning project)

 **Status:** Ongoing  
This repo is a personal learning project to explore building a simple genomic variant pipeline in Docker.

## Aim
Combined pipeline variant calling for both Long (ONT) and Short reads technologies
- **Short reads :** `fastp` → `bwa-mem2` → `samtools` (sort/markdup) → `bcftools` (SNP/indel calling)
- **Long reads:** `chopper` (quality trimming/filtering) → `minimap2` → `samtools` → **Clair3** (SNP/indel calling)

All tools run inside a Docker container for reproducibility.

## Requirements
- Docker
- A reference FASTA
-  FASTQ reads 


