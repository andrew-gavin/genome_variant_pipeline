# Genome Variant Pipeline (WIP)
Note: Project ongoing

## Aim
Combined pipeline variant calling for both Long (ONT) and Short reads technologies
- **Short reads :** `fastp` → `bwa-mem2` → `samtools` (sort/markdup) → `bcftools` (SNP/indel calling)
- **Long reads:** `chopper` (quality trimming/filtering) → `minimap2` → `samtools` → **Clair3** (SNP/indel calling)

All tools run inside a Docker container for reproducibility.

## Requirements
- Docker
- A reference FASTA
-  FASTQ reads 

## How to run:
Clone project locally:
```git clone https://github.com/andrew-gavin/genome_variant_pipeline```

Build docker image:
```docker build --no-cache -t genome-variant-pipeline:latest .```

Run in container:
```
	docker run --rm -v /abs/data:/data IMAGE \\
		--reads {short|long} \\
		--ref /data/ref/reference.fasta \\
		--r1 /data/fastq/sample_R1.fastq.gz [--r2 /data/fastq/sample_R2.fastq.gz] \\
		--sample SAMPLE_ID \\
		--threads 8 \\
		[--minlen 1000] [--minq 7] [--filtlong_keep 0.9]
```

Usage:

REQUIRED 

	--reads {short|long}      Pipeline mode: short=Illumina, long=ONT

	--ref PATH                Reference FASTA 

	--r1 PATH                 Read file (R1 or long-read FASTQ)

	--sample NAME             Sample name (used for output folder naming)

REQUIRED - SHORT READ ONLY

	--R2 PATH		Read 2 FASTQ

OPTIONAL - LONG READS ONLY

	--clair3_model NAME 	Clair3 model name (bioconda path)
				[defailt: r1041_e82_400bps_sup_v500]

	--minlen INT		Minimum read length [default: 1000]

OPTIONAL - Filtering (VCF files)

	--minq INT		 Variant QUAL cutoff [default: 7]

	--mindp INT		Min depth cutoff (INFO/DP for short; FMT/DP for long)
				[default: 5]
OTHER
	--threads INT		Threads [default: 4]
	--OUTDIR PATH		Output directory
	--help (-h)		Shows this message

Notes:
  * --reads short: uses fastp + bwa-mem2 (paired-end requires --r1 and --r2).
  * --reads long : uses NanoFilt/Filtlong + minimap2 (R1 only; gzip or plain fastq).
  * Outputs go to ./results/SAMPLE_ID/


