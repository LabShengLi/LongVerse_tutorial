#!/bin/bash
# Session 1: what has to exist before Session 2 and 3 run.
#
# Short version: Nextflow, Java 17 or newer, and one container engine. That is
# the whole list. Everything else, the pipeline itself and every tool image it
# uses, is fetched on demand by the commands in Session 2 and 3.
#
# This is the part that differs most from calling the tools by hand. A
# hand-written workflow has to pull each image, download each basecalling model
# and stage each input before it can start; LongVerse resolves all of that from
# the run command, so there is nothing to install per tool and nothing to keep
# in step with the pipeline version.
#
# [CARC] On USC CARC the three things are already there; load them and stop.
export PATH=/apps/generic/apptainer/1.5.3/bin:/apps/generic/openjdk/25.0.2/bin:/apps/generic/nextflow/25.10.4/bin:$PATH

# Elsewhere, install Nextflow once:
#   curl -fsSL https://get.nextflow.io | bash && sudo mv nextflow /usr/local/bin/
# and use Docker instead of Singularity by passing -profile docker.

nextflow -version
java -version
singularity --version 2>/dev/null || apptainer --version

# The container image cache. Images are several GB in total, so put it on a
# filesystem with room, not in a quota-limited home directory.
#
# [CARC] A shared cache already holds every image these sessions need, so on
# this cluster nothing is downloaded at all. It is world readable.
export NXF_SINGULARITY_CACHEDIR=/scratch1/yliu8962/longverse_cache
ls -lh "$NXF_SINGULARITY_CACHEDIR" | head

# Elsewhere, point it at a directory of your own and let Nextflow fill it:
#   export NXF_SINGULARITY_CACHEDIR=$HOME/longverse_cache

echo "### Session1 Done"
