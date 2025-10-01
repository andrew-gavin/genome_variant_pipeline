IMAGE_NAME ?= genome-variant-pipeline
TAG ?= latest

# Local data mount (adjust if needed)
DATA ?= $(PWD)/data

# Common args (container sees these under /data)
REF     ?= /data/ref/reference.fasta
R1      ?= /data/fastq/sample_R1.fastq.gz
R2      ?= /data/fastq/sample_R2.fastq.gz
LR1     ?= /data/fastq/sample_long.fastq.gz
SAMPLE  ?= SAMPLE1
THREADS ?= 8

# Long-read knobs (Chopper + Clair3)
MINLEN ?= 1000
MINQ ?= 7
CLAIR3_MODEL ?= r1041_e82_400bps_sup_v500

.PHONY: build run-short run-long shell help

build:
	docker build -t $(IMAGE_NAME):$(TAG) .

shell:
	docker run -it --rm -v $(DATA):/data --entrypoint bash $(IMAGE_NAME):$(TAG)

run-short: build
	docker run --rm -v $(DATA):/data $(IMAGE_NAME):$(TAG) \
	  --reads short \
	  --ref $(REF) \
	  --r1 $(R1) \
	  --r2 $(R2) \
	  --sample $(SAMPLE) \
	  --threads $(THREADS)

run-long: build
	docker run --rm -v $(DATA):/data $(IMAGE_NAME):$(TAG) \
	  --reads long \
	  --ref $(REF) \
	  --r1 $(LR1) \
	  --sample $(SAMPLE) \
	  --threads $(THREADS) \
	  --minlen $(MINLEN) \
	  --minq $(MINQ) \
	  --clair3_model $(CLAIR3_MODEL) \

