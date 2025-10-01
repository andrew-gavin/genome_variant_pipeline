#!/usr/bin/env bash
set -euo pipefail



## Default ARguments
THREADS=4
SAMPLE="sample"
REF=""
R1=""
R2=""
READS="short" # short or long
MINLEN=1000
MINQ=7
FILTLONG_KEEP=0.9
CLAIR3_MODEL="r1041_e82_400bps_sup_v500"
OUTDIR="results"

## inputted args

while [[ $# -gt 0 ]]; do
	case $1 in
		--reads) READS="$2"; shift 2 ;;
		--ref) REF="$2"; shift 2 ;;
		--r1) R1="$2"; shift 2 ;;
		--r2) R2="$2"; shift 2 ;;
		--sample) SAMPLE="$2"; shift 2 ;;
		--threads) THREADS="$2"; shift 2 ;;
		--minlen) MINLEN="$2"; shift 2 ;;
		--minq) MINQ="$2"; shift 2 ;;
		--filtlong_keep) FILTLONG_KEEP="$2"; shift 2 ;;
		--clair3_model) CLAIR3_MODEL="$2"; shift 2 ;;
		*) echo "Unknown arg: $1" >&2; exit 1 ;;
	esac
done


## check required inputs

[[ -f "$REF" ]] || { echo "Missing --ref $REF" >&2; exit 1; }
[[ -f "$R1" ]] || { echo "Missing --r1 $R1" >&2; exit 1; }

## Only check paired reads for short reads

if [[ "$READS" == "short" ]]; then
  [[ -f "$R2" ]] || { echo "For --reads short, --r2 is required." >&2; exit 1; }
fi


## Output directory
OD="${OUTDIR}/${SAMPLE}"
mkdir -p "$OD"



#########################------------------------------------------  Index reference file -------------------------------------#####################################

echo "[1/7] Indexing reference files (if required)" 

if [[ "$READS" == "short" ]]; then
  if [[ ! -f "${REF}.0123" ]]; then
    bwa-mem2 index "$REF"
  fi
else
  if [[ ! -f "${REF}.mmi" ]]; then
    minimap2 -d "${REF}.mmi" "$REF"
  fi
fi


if [[ ! -f "${REF}.fai" ]]; then
  samtools faidx "$REF"
fi


#########################------------------------------------------  Quality Control -------------------------------------#####################################

echo "[2/7] QC & trimming"

if [[ "$READS" == "short" ]]; then
	echo "[2/7] QC & trimming (fastp, short reads)"
	fastp -i "$R1" -I "$R2" \
        	-o "$OD/${SAMPLE}_R1.trim.fastq.gz" -O "$OD/${SAMPLE}_R2.trim.fastq.gz" \
	        -w "$THREADS" -h "$OD/fastp.html" -j "$OD/fastp.json"
	R1_CLEAN="$OD/${SAMPLE}_R1.trim.fastq.gz"
	R2_CLEAN="$OD/${SAMPLE}_R2.trim.fastq.gz"
else
	CLEAN="$OD/${SAMPLE}.clean.fastq.gz"
	chopper \
		--trim-approach trim-by-quality \
		--cutoff "$MINQ" \
		-q "$MINQ" \
		-l "$MINLEN" \
		-t "$THREADS" \
		-i "$R1" \
	| gzip -c > "$CLEAN"
	R1_CLEAN="$CLEAN"
fi



#########################------------------------------------------ Alignment -------------------------------------#####################################

echo "[3/7] Aligning (minimap2 for long, bwa-mem2 for short)"

if [[ "$READS" == "short" ]]; then
	bwa-mem2 mem -t "$THREADS" "$REF" "$R1_CLEAN" "$R2_CLEAN" \
		| samtools view -b -@ "$THREADS" -o "$OD/aligned.bam" -
else
	minimap2 -t "$THREADS" -x map-ont "$REF" "$R1_CLEAN" \
		| samtools view -b -@ "$THREADS" -o "$OD/aligned.bam" -
fi


###########################--------------------------------------- Sort & de-dup (short reads) ---------------------#########################################


echo "[4/7] Sorting reads"

samtools sort -@ "$THREADS" -o "$OD/aligned.sorted.bam" "$OD/aligned.bam"
rm -f "$OD/aligned.bam"


echo "[4.5/7] Deduplicating (short reads only)"

if [[ "$READS" == "short" ]]; then
	samtools fixmate -@ "$THREADS" -m "$OD/aligned.sorted.bam" "$OD/fixed.bam"
	samtools sort -@ "$THREADS" -o "$OD/fixed.sorted.bam" "$OD/fixed.bam"
	samtools markdup -@ "$THREADS" -s "$OD/fixed.sorted.bam" "$OD/dedup.bam"
	mv "$OD/dedup.bam" "$OD/final.bam"
	samtools index "$OD/final.bam"
else
	mv "$OD/aligned.sorted.bam" "$OD/final.bam"
	samtools index "$OD/final.bam"
fi


###########################--------------------------------------- Variant calling ---------------------#########################################


echo "[6/7] Variant calling"

if [[ "$READS" == "short" ]]; then
	 bcftools mpileup -Ou -f "$REF" "$OD/final.bam" \
		| bcftools call -Ou -mv \
		| bcftools filter -s LowQual -e '%QUAL<10 || DP<5' -Oz -o "$OD/variants.vcf.gz"
	tabix -p vcf "$OD/variants.vcf.gz"
else
	OD_ABS="$(cd "$OD"; pwd)" # clair3 recomends absolute paths
	CLAIR3_BINDIR="$(dirname "$(which run_clair3.sh)")"
	MODEL_PATH="${CLAIR3_BINDIR}/models/${CLAIR3_MODEL}"
	
	# run clair3
	run_clair3.sh \
		--bam_fn="$OD/dedup.bam" \
		--ref_fn="$REF" \
		--threads="$THREADS" \
		--platform=ont \
		--model_path="$MODEL_PATH" \
		--output="$OD_ABS/clair3" 
	cp "$OD/clair3/merge_output.vcf.gz" "$OD/variants.vcf.gz
	tabix -p vcf "$OD/variants.vcf.gz"
fi



#########################################---------------------- Wrap up ----------------------###################################

echo "[7/7] Done."
echo "Results in: $OD"
