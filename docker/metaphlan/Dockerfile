FROM mambaorg/micromamba:1.5.8 as app

ARG METAPHLAN_VER="4.1.0"

USER root

WORKDIR /

LABEL base.image="mambaorg/micromamba:1.5.8"
LABEL dockerfile.version="1"
LABEL software="MetaPhlAn"
LABEL software.version="${METAPHLAN_VER}"
LABEL description="MetaPhlAn is a computational tool for species-level microbial profiling from metagenomic shotgun sequencing data"
LABEL website="https://github.com/biobakery/MetaPhlAn"
LABEL license="https://github.com/biobakery/MetaPhlAn/blob/master/license.txt"
LABEL maintainer="Sunit Jain"
LABEL maintainer.email="sunitj@stanford.edu"

RUN apt-get update && apt-get install --no-install-recommends -y \
    procps &&\
    apt-get autoclean && rm -rf /var/lib/apt/lists/*

RUN micromamba install --name base -c conda-forge -c bioconda metaphlan=${METAPHLAN_VER} &&\
    micromamba clean -a -y

ENV PATH="/opt/conda/bin/:${PATH}" \
    LC_ALL=C.UTF-8

WORKDIR /opt/work

CMD ["/bin/sh","-c","/bin/bash"]
