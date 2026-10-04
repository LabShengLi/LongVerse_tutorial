# LongVerse_tutorial

Running [LongVerse](https://github.com/LabShengLi/longverse) on long-read data from
the command line: raw signal to allele-specific methylation in one command, for
Oxford Nanopore and PacBio HiFi.

LongVerse is a Nextflow DSL2 pipeline. It takes raw reads through basecalling to a
modified-base BAM, extracts per-read and per-site methylation, calls variants,
phases the reads into haplotypes, and reports methylation per haplotype.

## What you need

Nextflow, Java 17 or newer, and one container engine (Docker, Singularity or
Apptainer). That is the whole list. The pipeline is pulled from GitHub and the
tool images and test data are fetched on demand, so there is nothing to install
per tool.

## Sessions

| | | |
|---|---|---|
| 1 | [Session1_setup.sh](script/Session1_setup.sh) | What has to exist first, and the shared image cache |
| 2 | [Session2_ont_one_command.sh](script/Session2_ont_one_command.sh) | ONT: POD5 to per-haplotype methylation |
| 3 | [Session3_pacbio_one_command.sh](script/Session3_pacbio_one_command.sh) | PacBio HiFi: kinetics to per-haplotype methylation |

Run times and the full console output of a real run are in
[Session_jobinfo.md](script/Session_jobinfo.md).

## The data

A 120,358 bp window around the GNAS imprinted locus on chromosome 20 of HG002,
aligned to CHM13v2.0 (T2T), published on Zenodo at
[10.5281/zenodo.20116126](https://doi.org/10.5281/zenodo.20116126). ONT and PacBio
HiFi versions of the same locus, a few MB each.

GNAS is imprinted, which is the point: the two haplotypes genuinely differ, so a
run that phases correctly produces two clearly different methylation profiles
rather than two copies of the same thing.

Nothing has to be downloaded first. The commands reference the Zenodo URLs and
Nextflow stages them.

## ONT, one command

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
extracted per read and unified per site, Clair3 calls variants, whatshap splits
the reads into HP1 and HP2, and the methylation is re-extracted for each
haplotype. About three minutes on four CPU cores.

## PacBio HiFi, one command

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
basecalling step of its own**. A HiFi BAM already carries the polymerase kinetics,
and Jasmine calls 5mC from them. Everything after that, alignment with pbmm2,
extraction, Clair3, phasing, is the shared stack. About ninety seconds.

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

The haplotype BAMs carry MM/ML tags, so they can be loaded into IGV and coloured
by base modification directly.

## Three things that will bite you

**The contig is not called `chr20`.** The reference is a window, and its single
contig is named `chr20:60574425-60694782`. That string is the whole contig name,
not a region on chr20, and positions inside it start at 1, not at 60,574,425.
Passing the bare chromosome name to `--chrSet` does not fail: it produces an empty
result and exits 0.

**The exit code is not the answer.** The pipeline sets `errorStrategy = 'ignore'`
so that one failed step does not abandon the rest of the run. Nextflow then
returns 0 whether or not something failed, and reports it only as `Ignored : N` in
its own summary. Read the summary, not `$?`.

**Everything the container touches has to be bound.** `--containerOptions "-B $PWD"`
is not decoration. If `TMPDIR` points somewhere the container engine does not
mount, several steps fail the moment they start, because they run GNU parallel and
it creates a temp file before doing anything else. Combined with the point above,
that produces a run which exits 0 having done half the work.

## Adapting this elsewhere

Lines marked `[CARC]` in the scripts are specific to the USC CARC cluster: where
Apptainer, Java and Nextflow live, and where the shared image cache is. Replace
those three lines and the rest works anywhere. With Docker, use `-profile docker`
and drop `--containerOptions`, since Docker mounts what Nextflow uses.

## Links

* Pipeline: [LabShengLi/longverse](https://github.com/LabShengLi/longverse)
* Data: [10.5281/zenodo.20116126](https://doi.org/10.5281/zenodo.20116126)
* Figures from the paper: [LabShengLi/longverse-figures](https://github.com/LabShengLi/longverse-figures)
