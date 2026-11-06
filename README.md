# ![nfcore/test-datasets](docs/images/test-datasets_logo.png)

# genomic-medicine-sweden/test-datasets: `autoseq` branch

Test data for the [autoseq](https://github.com/genomic-medicine-sweden/autoseq) pipeline's `-profile test` / `-profile test_umi` and its module/subworkflow nf-tests.

> ⚠️ **Do not merge this branch into `master`!** Each pipeline has a dedicated branch in this repository.

## Using this data

Clone only this branch:

```bash
git clone https://github.com/genomic-medicine-sweden/test-datasets.git --single-branch --branch autoseq
```

Raw base URL for `pipelines_testdata_base_path`:

```
https://raw.githubusercontent.com/genomic-medicine-sweden/test-datasets/refs/heads/autoseq/
```

## Layout

```
reference/GRCh37/
  genome/                FASTA + .fai + .dict (sarek "small" b37 decoy)
  annotations/           dbSNP + gnomAD (sarek small subsets), cancer-gene curation CSV
  targets/               test_panel slopped BED + interval_list, jumble reference RDS
  gridss/                GRIDSS PON, known fusions, repeatmasker, gridss.properties
  hmfdata/               SAGE PON, somatic hotspots, high-confidence regions
  gridss_index.tar.gz    GRIDSS BWA index
  ensembl_data.tar.gz    HMF Ensembl-data cache subset
  vep.tar.gz             Ensembl VEP cache skeleton (homo_sapiens/115_GRCh37)
testdata/
  csv/                   samplesheet_grch37.csv (test), samplesheet_grch37_umi.csv (test_umi)
  fastqs/GRCh37/         sarek tiny tumor/normal FASTQs (2 lanes per sample)
  fastqs/GRCh37_umi/     sarek tiny tumor/normal FASTQs with UMIs (2 lanes per sample)
  bam/                   deduplicated TUMOR, NORMAL and 1234T BAMs
  vcf/                   HaplotypeCaller, Mutect2/SAGE PASS-only and VEP-annotated somatic VCFs
  gridss/                GRIDSS SV VCF (GRIPSS tests)
  jumble/                Jumble CNV segments + calls (tumor, normal)
  purecn/                CNVkit cnr/seg + Mutect2 calls (PureCN tests)
  annotate_cnvs/         CNV segments + cancer-gene annotation CSV
scripts/
  curate_test_data.sh          Regenerates genome, annotations, targets, FASTQs and samplesheets from upstream sources
  make_umi_test_fastqs.sh      Builds GRCh37_umi FASTQs + samplesheet
  make_mock_ensembl_data.sh    Builds the HMF ensembl_data subset
  make_mock_gridss_vcf.py      Builds testdata/gridss/TUMOR_NORMAL.gridss.vcf.gz
  make_mock_jumble_reference.R Builds the mock jumble reference RDS
```

Only files referenced by the autoseq pipeline are kept. Tarballs are unpacked by the `PREPARE_REFERENCES` subworkflow.

## Regenerating

```bash
bash scripts/curate_test_data.sh
```

Pulls source files from the `sarek` and `modules` branches of nf-core/test-datasets into `.staging/` (gitignored) and writes outputs into `reference/` and `testdata/`. Requires `samtools`, `bcftools`, `bedtools`, `bwa`, `tabix`, `bgzip`. See each script's header for usage.

## Synthesized files

HMF/SAGE/GRIDSS resources have no public downsampled equivalents; minimal-but-valid versions are used:

| File | Form |
| --- | --- |
| `hmfdata/KnownHotspots.somatic.37.vcf.gz` | VCF header only, contigs from the FASTA index |
| `hmfdata/SageGermlinePon.1000x.37.tsv.gz` | Column header only |
| `hmfdata/NA12878_GIAB_*_highconf.bed.gz`, `gridss/sgl_pon.37.bed.gz` | One placeholder BED record |
| `gridss/sv_pon.37.bedpe.gz`, `gridss/known_fusions.37.bedpe` | One placeholder BEDPE entry |
| `gridss/repeat_mask_data.37.fa.gz` | Single short simple-repeat sequence |
| `ensembl_data.tar.gz` | Public Ensembl records subset to the test contigs |
| `annotations/cancer_gene_annotations_for_curation.37.v2.csv` | Header + one placeholder row |
| `targets/test_panel.bed.reference.RDS` | Mock jumble reference with dummy counts |
| `testdata/gridss/TUMOR_NORMAL.gridss.vcf.gz` | GRIDSS header + five synthetic breakend pairs |

These allow SAGE / GRIDSS / GRIPSS / annotation steps to run but do not produce biologically meaningful calls.
