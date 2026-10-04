# LongVerse tutorial

Running [LongVerse](https://github.com/LabShengLi/longverse) on long-read data from
the command line: raw signal to allele-specific methylation in one command, for
Oxford Nanopore and PacBio HiFi.

LongVerse is a Nextflow DSL2 pipeline. It takes raw reads through basecalling to a
modified-base BAM, extracts per-read and per-site methylation, calls variants,
phases the reads into haplotypes, and reports methylation per haplotype.

---

## Section 1: Software Installation

### Prerequisite

You must have access to [CARC OnDemand](https://ondemand.carc.usc.edu/pun/sys/dashboard/)
and be able to start a Cluster Shell Access session.

![On_Demand_Shell](pic/ondemand_shell_app.png)

### Enter into interactive mode

**Note**: if you are already in compute node mode, you don't need to do this step.

This command starts an interactive session on the cluster with multiple CPU cores
and memory. More information in the
[Slurm Job documents](https://www.carc.usc.edu/user-guides/hpc-systems/using-our-hpc-systems/slurm-templates.html)
for CARC HPC.

```
## srun --pty -p main --time=02:00:00 -n 8 --mem 32GB bash
salloc -p debug -c 8 --mem 32GB --time 2:00:00
```

**Note: You must enter the `compute` (`interactive`) mode to load and run most
software, not the `login` mode.**

---

Create and enter a directory for this session's work:

```bash
wdir="/scratch1/$USER/longverse_tutorial"
mkdir -p $wdir
cd $wdir
pwd
```

### What LongVerse needs

Nextflow, Java 17 or newer, and one container engine. That is the whole list.

This is the part that differs most from calling the tools by hand. A hand-written
workflow has to pull each image, download each basecalling model and stage each
input before it can start. LongVerse resolves all of that from the run command, so
there is nothing to install per tool and nothing to keep in step with the pipeline
version.

#### Singularity container

[**Singularity**](https://docs.sylabs.io/guides/3.5/user-guide/introduction.html)
is a container technology designed to run applications in a portable and
reproducible way, especially in high-performance computing environments. Unlike
Docker, which often requires administrator (root) privileges, Singularity is built
to work securely on shared systems where users do not have root access.

Singularity packages all the software, libraries and dependencies of a workflow
into a single container file, so the analysis runs the same way on any system
regardless of the underlying operating system or installed software.

```bash
module load apptainer
singularity --version
```

#### Install Java and Nextflow

Nextflow requires Java 17 or higher.

```bash
module spider openjdk
module load openjdk/21.0.0_35
```

[Nextflow](https://www.nextflow.io/docs/latest/install.html#install-nextflow) can
be installed with a single command:

```bash
curl -s https://get.nextflow.io | bash
./nextflow -v
```

Or by module:

```bash
module purge
module load ver/2506 gcc/14.3.0 openjdk/21.0.7_6 nextflow/25.04.8 apptainer
```

On this cluster all three are already installed, so one PATH line is enough:

```bash
# [CARC]
export PATH=/apps/generic/apptainer/1.5.3/bin:/apps/generic/openjdk/25.0.2/bin:/apps/generic/nextflow/25.10.4/bin:$PATH
```

#### The container image cache

Images total several GB, so put the cache on a filesystem with room, not in a
quota-limited home directory.

```bash
# [CARC] A shared cache already holds every image this tutorial needs, world
# readable, so nothing is downloaded on this cluster.
export NXF_SINGULARITY_CACHEDIR=/scratch1/yliu8962/longverse_cache
```

Elsewhere, point it at a directory of your own and let Nextflow fill it:

```bash
export NXF_SINGULARITY_CACHEDIR=$HOME/longverse_cache
```

Full script: [Session1_setup.sh](script/Session1_setup.sh)

---

## The data

A 120,358 bp window around the GNAS imprinted locus on chromosome 20 of HG002,
aligned to CHM13v2.0 (T2T), published on Zenodo at
[10.5281/zenodo.20116126](https://doi.org/10.5281/zenodo.20116126). ONT and PacBio
HiFi versions of the same locus, a few MB each.

GNAS is imprinted, which is the point: the two haplotypes genuinely differ, so a
run that phases correctly produces two clearly different methylation profiles
rather than two copies of the same thing.

Nothing has to be downloaded first. The commands below reference the Zenodo URLs
and Nextflow stages them.

**The contig is not called `chr20`.** The reference is a window and its single
contig is named `chr20:60574425-60694782`. That string is the whole contig name,
not a region on chr20, and positions inside it start at 1. Passing the bare
chromosome name to `--chrSet` does not fail: it produces an empty result and
exits 0.

---

## Section 2: ONT, raw signal to per-haplotype methylation

```bash
Z=https://zenodo.org/records/23090404/files

nextflow run LabShengLi/longverse -latest -profile singularity --dsname ont \
    --input $Z/chr20_GNAS_ont_pod5.tar.gz --genome $Z/chr20_GNAS_ref.tar.gz \
    --platform ont --ecosystem dorado --input_bam false --file_format pod5 --phasing true \
    --dorado_basecall_model 'dna_r10.4.1_e8.2_400bps_hac@v4.1.0' \
    --dorado_methcall_model 'dna_r10.4.1_e8.2_400bps_hac@v4.1.0_5mCG_5hmCG@v2' \
    --chrSet chr20:60574425-60694782 --ctg_name chr20:60574425-60694782 \
    --clair3_platform ont --CLAIR3_MODEL_NAME r1041_e82_400bps_hac_v410 \
    --outdir ont --containerOptions "-B $PWD"
```

Fifteen steps: Dorado basecalls the POD5 and calls 5mC, the methylation is
extracted per read and unified per site, Clair3 calls variants, whatshap splits the
reads into HP1 and HP2, and the methylation is re-extracted for each haplotype.
**2 min 57 s** on four CPU cores, no GPU.

Script: [Session2_ont_one_command.sh](script/Session2_ont_one_command.sh) ·
Console output: [Session2_ont.log](script/Session2_ont.log)

### IGV visualization of methylation states in BAM file

Open OnDemand Traveller Desktop, start IGV Viewer, and load the modified-base BAM
from `ont/ont-*/`. The MM/ML tags are already there, so IGV can colour the reads by
base modification directly.

![IGV Snapshot of KCNQ1](pic/igv_snapshot_KCNQ1.png)

![IGV Snapshot of SNRPN](pic/igv_snapshot_SNRPN.png)

---

## Section 3: PacBio HiFi, kinetics to per-haplotype methylation

```bash
Z=https://zenodo.org/records/23090404/files

nextflow run LabShengLi/longverse -latest -profile singularity --dsname pacbio \
    --input $Z/chr20_GNAS_pacbio_kinetics.tar.gz --genome $Z/chr20_GNAS_ref.tar.gz \
    --platform pacbio --ecosystem jasmine --input_bam false --file_format bam --phasing true \
    --chrSet chr20:60574425-60694782 --ctg_name chr20:60574425-60694782 \
    --clair3_platform hifi --CLAIR3_MODEL_NAME hifi_sequel2 \
    --outdir pacbio --containerOptions "-B $PWD"
```

The same sixteen steps with one difference at the front: **PacBio has no
basecalling step of its own**. A HiFi BAM already carries the polymerase kinetics
and Jasmine calls 5mC from them. Everything after that, alignment with pbmm2,
extraction, Clair3, phasing, is the shared stack. **1 min 03 s**.

Script: [Session3_pacbio_one_command.sh](script/Session3_pacbio_one_command.sh) ·
Console output: [Session3_pacbio.log](script/Session3_pacbio.log)

### IGV visualization of haplotype phasing

Load the two haplotype BAMs from `pacbio/pacbio-vcall/pacbio_phased_bam/` as
separate tracks. At an imprinted locus the two tracks separate cleanly, which is
what a correct phasing looks like.

![IGV Snapshot of MethPhase](pic/igv_snapshot_methphase.png)

---

## Results

```
ont/
├── ont-methylation-callings/
│   ├── Read_Level-ont_{all,HP1,HP2}/      per-read CpG calls
│   └── Site_Level-ont_{all,HP1,HP2}/      per-site methylation, NANOME / methylKit / DSS formats
├── ont-vcall/
│   ├── ont_clair3_out/                    variants
│   └── ont_phased_bam/ont_{HP1,HP2}/      the haplotype BAMs
├── ont-LVQC/                              read length, quality, coverage
└── ont_DMC/                               differentially methylated cytosines, HP1 vs HP2
```

Run times, the step lists and how to tell a run actually worked are in
[Session_jobinfo.md](script/Session_jobinfo.md).

---

## Adapting this elsewhere

Lines marked `[CARC]` are specific to the USC CARC cluster: where Apptainer, Java
and Nextflow live, and where the shared image cache is. Replace those and the rest
works anywhere. With Docker, use `-profile docker` and drop `--containerOptions`,
since Docker mounts what Nextflow uses.

## Links

* Pipeline: [LabShengLi/longverse](https://github.com/LabShengLi/longverse)
* Data: [10.5281/zenodo.20116126](https://doi.org/10.5281/zenodo.20116126)
* Figures from the paper: [LabShengLi/longverse-figures](https://github.com/LabShengLi/longverse-figures)
* Course tutorial this is modelled on: [BIOC599_LongRead](https://labshengli.github.io/BIOC599_LongRead/)
