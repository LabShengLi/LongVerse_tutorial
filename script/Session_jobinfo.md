# Run times

Measured 2026-10-04 on a USC CARC compute node, 8 cores allocated and
`--processors 4` passed to the pipeline. No GPU. The full console output of these
two runs is in `Session2_ont.log` and `Session3_pacbio.log`.

| Session | Steps | Wall clock |
|---|---|---|
| 2, ONT, POD5 to per-haplotype methylation | 15 | **2 min 57 s** |
| 3, PacBio HiFi, kinetics to per-haplotype methylation | 16 | **1 min 03 s** |

Both runs completed every step with nothing failed and nothing ignored.

ONT takes three times as long for one reason: it basecalls. Dorado reads 23 MB of
POD5 on CPU, which is most of those three minutes. PacBio has no basecalling step
of its own, so Jasmine starts from the kinetics the HiFi BAM already carries and
the run is dominated by Clair3 instead.

Neither number includes downloading container images. They were already in the
shared cache, so this run pulled nothing. A first run on a machine with an empty
cache pulls several GB and that will dominate the wall clock, once.

## What the steps are

ONT, 15 steps:

```
ENVCHECK  GENOME  DORADO_UNTAR  DORADO_CALL  LV_QC  LV_CALL_EXTRACT  UNIFY
LV_CLAIR3  LV_PHASING  LV_CALL_EXTRACT_POST_HP1  LV_CALL_EXTRACT_POST_HP2
UNIFY_POST_HP1  UNIFY_POST_HP2  LV_DMC_METHYLKIT  MULTIQC_METHYLATION
```

PacBio, 16 steps: the same list with `DORADO_UNTAR` and `DORADO_CALL` replaced by
`PB_UNTAR`, `PB_JASMINE` and `PB_PBMM2`. Jasmine calls the methylation, pbmm2
aligns, and everything from `LV_QC` onwards is shared between the platforms.

## How to tell a run actually worked

Not from the exit code. The pipeline sets `errorStrategy = 'ignore'` so that one
failed step does not abandon the rest, and Nextflow then returns 0 either way.

Nextflow normally prints a summary at the end:

```
Completed at: 04-Oct-2026 15:01:16
Duration    : 2m 56s
Succeeded   : 15
```

with an `Ignored : N` line when `errorStrategy` swallowed something. That summary
is the thing to read. Note that it is not always printed: the PacBio run recorded
here finished all 16 steps and never emitted it. When it is missing, count the
`✔` marks, or pass `-with-trace` and count the non-COMPLETED rows.
