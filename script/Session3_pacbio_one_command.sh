#!/bin/bash
# LongVerse on the chr20 GNAS PacBio HiFi test data: kinetics to per-haplotype
# methylation in one run. Jasmine calls 5mC from the kinetics the HiFi BAM
# carries, pbmm2 aligns, Clair3 calls variants, whatshap splits the reads, and
# the methylation is re-extracted per haplotype. PacBio has no basecalling step
# of its own; Jasmine is the caller.
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

nextflow run LabShengLi/longverse -latest -profile singularity --dsname pacbio \
    --input $Z/chr20_GNAS_pacbio_kinetics.tar.gz --genome $Z/chr20_GNAS_ref.tar.gz \
    --platform pacbio --ecosystem jasmine --input_bam false --file_format bam --phasing true \
    --chrSet chr20:60574425-60694782 --ctg_name chr20:60574425-60694782 \
    --clair3_platform hifi --CLAIR3_MODEL_NAME hifi_sequel2 \
    --outdir pacbio --containerOptions "-B $PWD"
