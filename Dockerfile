# Dockerfile

FROM mambaorg/micromamba:1.5.5

USER root

ENV PATH=/opt/conda/bin:$PATH

WORKDIR /app

#Install required tools

RUN micromamba install -y -n base -c conda-forge -c bioconda \
	bwa-mem2=2.2.1 \
	minimap2=2.28 \
	samtools=1.20 \
	bcftools=1.20 \
	fastp=0.23.4 \
	chopper=0.11.0 \
	clair3=1.2.0 \
	&& micromamba clean -a -y


# Prepare variant pipeline script

COPY variant_pipe.sh /app/variant_pipe.sh
RUN chmod +x /app/variant_pipe.sh

# Default work directory for data mounting
WORKDIR /data

ENTRYPOINT ["/app/variant_pipe.sh"]
