#!/bin/bash
# LongVerse on the chr20 GNAS ONT test data: POD5 to per-haplotype methylation in
# one run. Dorado basecalls and calls 5mC, Clair3 calls variants, whatshap splits
# the reads, and the methylation is re-extracted per haplotype.
# Input and reference come from Zenodo, the pipeline from GitHub: nothing to
# download first. -latest re-pulls the pipeline, because `nextflow run <repo>`
# otherwise reuses whatever was cached in $NXF_HOME/assets, however old.
#
# chr20:60574425-60694782 is a CONTIG NAME, not a region on chr20. The reference is
# a 120,358 bp window whose positions start at 1.
#
# errorStrategy = 'ignore' means Nextflow exits 0 even when a task failed, and
# says so only as "Error is ignored" in its own output. Read the run summary,
# not the exit code.
#
# [CARC] The three exports are cluster-specific.
# The cache is shared and world readable, so nobody on this cluster re-downloads
# the 34 GB of images. It is on /scratch1, which is not backed up and is purged
# when the filesystem fills: fine for a cache, which Nextflow refills on demand.
# Point it somewhere of your own elsewhere.
# The bind matters because this site's Apptainer maps /project2 but NOT
# /scratch1, so an inherited TMPDIR is invisible inside the container and the
# untar step dies there.
export PATH=/apps/generic/apptainer/1.5.3/bin:/apps/generic/openjdk/25.0.2/bin:/apps/generic/nextflow/25.10.4/bin:$PATH
export NXF_SINGULARITY_CACHEDIR=/scratch1/yliu8962/longverse_cache
export TMPDIR=$PWD/tmp; mkdir -p "$TMPDIR"

Z=https://zenodo.org/records/23090404/files

nextflow run LabShengLi/longverse -latest -profile singularity --dsname ont \
    --input $Z/chr20_GNAS_ont_pod5.tar.gz --genome $Z/chr20_GNAS_ref.tar.gz \
    --platform ont --ecosystem dorado --input_bam false --file_format pod5 --phasing true \
    --dorado_basecall_model 'dna_r10.4.1_e8.2_400bps_hac@v4.1.0' \
    --dorado_methcall_model 'dna_r10.4.1_e8.2_400bps_hac@v4.1.0_5mCG_5hmCG@v2' \
    --chrSet chr20:60574425-60694782 --ctg_name chr20:60574425-60694782 \
    --clair3_platform ont --CLAIR3_MODEL_NAME r1041_e82_400bps_hac_v410 \
    --outdir ont --containerOptions "-B $PWD"
