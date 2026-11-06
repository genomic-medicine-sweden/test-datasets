#!/usr/bin/env bash
#
# curate_test_data.sh — regenerate the GRCh37 reference files, FASTQs and
# samplesheet used by autoseq's `-profile test` on the
# genomic-medicine-sweden/test-datasets `autoseq` branch.
#
# Sources (sarek branch of nf-core/test-datasets):
#   - small b37 decoy FASTA, dbSNP/gnomAD small VCFs, tiny tumor/normal FASTQs
#
# Synthesized in-place (minimal-but-valid):
#   - reference/GRCh37/hmfdata/   KnownHotspots.somatic, SageGermlinePon, NA12878 highconf BED
#   - reference/GRCh37/gridss/    sgl_pon, sv_pon, known_fusions, repeatmasker
#   - reference/GRCh37/gridss_index.tar.gz
#   - reference/GRCh37/targets/   slopped20 BED + interval_list
#   - testdata/csv/samplesheet_grch37.csv
#
# Not produced here:
#   - reference/GRCh37/gridss/gridss.properties                  (hand-maintained)
#   - reference/GRCh37/annotations/cancer_gene_annotations_for_curation.37.v2.csv (hand-maintained)
#   - reference/GRCh37/vep.tar.gz                                (hand-built VEP cache skeleton)
#   - reference/GRCh37/ensembl_data.tar.gz                       (make_mock_ensembl_data.sh)
#   - reference/GRCh37/targets/test_panel.bed.reference.RDS      (make_mock_jumble_reference.R)
#   - testdata/fastqs/GRCh37_umi + samplesheet_grch37_umi.csv    (make_umi_test_fastqs.sh)
#   - testdata/gridss/TUMOR_NORMAL.gridss.vcf.gz                 (make_mock_gridss_vcf.py)
#
# Usage:
#   bash scripts/curate_test_data.sh
#
# Idempotent: downloads are cached, synthesized files are overwritten,
# files listed under "Not produced here" are left untouched.

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths and tool resolution
# ---------------------------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGING="${REPO_ROOT}/.staging"
REF_ROOT="${REPO_ROOT}/reference/GRCh37"
TEST_ROOT="${REPO_ROOT}/testdata"

SAREK_RAW="https://raw.githubusercontent.com/nf-core/test-datasets/sarek"

NFCORE_ENV="${HOME}/micromamba/envs/nf-core-env/bin"
TBPROF_ENV="${HOME}/micromamba/envs/tb-profiler/bin"

SAMTOOLS="${NFCORE_ENV}/samtools"
TABIX="${NFCORE_ENV}/tabix"
BGZIP="${NFCORE_ENV}/bgzip"
BEDTOOLS="${TBPROF_ENV}/bedtools"
BWA="${TBPROF_ENV}/bwa"

# GitHub raw URL prefix for samplesheet CSVs (so nf-test can stage them remotely)
TESTDATA_RAW="https://raw.githubusercontent.com/genomic-medicine-sweden/test-datasets/refs/heads/autoseq"

# Anchor region used by all synthetic single-record files (inside the test panel).
ANCHOR_CHROM="1"
ANCHOR_START="132700"
ANCHOR_END="139738"
ANCHOR_GENE="TEST_GENE_37"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; }

# Download a file only if not already present.
fetch() {
    local url="$1" dest="$2"
    if [[ -s "${dest}" ]]; then
        log "  cached: ${dest##*/}"
        return 0
    fi
    mkdir -p "$(dirname "${dest}")"
    log "  fetch:  ${url##*/}"
    curl -fsSL "${url}" -o "${dest}.tmp"
    mv "${dest}.tmp" "${dest}"
}

require_tools() {
    local missing=0
    for t in "${SAMTOOLS}" "${TABIX}" "${BGZIP}" "${BEDTOOLS}" "${BWA}"; do
        if [[ ! -x "${t}" ]]; then
            echo "ERROR: missing tool: ${t}" >&2
            missing=1
        fi
    done
    [[ ${missing} -eq 0 ]] || exit 1
}

# Minimal valid bgzipped VCF with fai-derived contig lines and an empty body.
write_empty_vcf_gz() {
    local fai="$1" out="$2"
    {
        echo "##fileformat=VCFv4.2"
        awk '{ printf "##contig=<ID=%s,length=%s>\n", $1, $2 }' "${fai}"
        echo -e "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO"
    } | "${BGZIP}" -c > "${out}"
}

# SAGE germline PON TSV — header only, bgzipped.
write_empty_sage_pon_tsv_gz() {
    printf "Chromosome\tPosition\tRef\tAlt\tCount\n" | "${BGZIP}" -c > "$1"
}

# Plain BED with one entry.
write_singleton_bed() {
    local out="$1" chrom="$2" start="$3" end="$4" name="$5"
    printf "%s\t%s\t%s\t%s\n" "${chrom}" "${start}" "${end}" "${name}" > "${out}"
}

# Bgzipped BED with one entry.
write_singleton_bed_gz() {
    local out="$1" chrom="$2" start="$3" end="$4" name="$5"
    printf "%s\t%s\t%s\t%s\n" "${chrom}" "${start}" "${end}" "${name}" | "${BGZIP}" -c > "${out}"
}

# GRIPSS single-breakend PON BED.gz with one entry.
# GRIPSS PonSglRegion.fromBedRecord reads 6 columns: Chr, PosBegin, PosEnd,
# Unknown, PonCount(int), Orientation(+/-). A 4-column BED crashes GRIPSS with
# ArrayIndexOutOfBounds at items[5].
write_singleton_sgl_pon_gz() {
    local out="$1" chrom="$2" start="$3" end="$4"
    printf "%s\t%s\t%s\t%s\t%s\t%s\n" "${chrom}" "${start}" "${end}" "." "1" "+" | "${BGZIP}" -c > "${out}"
}

# BEDPE placeholder line: chr1 start1 end1 chr2 start2 end2 name score strand1 strand2
bedpe_line() {
    local chrom="$1" pos="$2"
    printf "%s\t%d\t%d\t%s\t%d\t%d\tplaceholder\t0\t+\t-\n" \
        "${chrom}" "${pos}" "$((pos+1))" "${chrom}" "$((pos+500))" "$((pos+501))"
}

# Minimal repeatmasker FASTA (one short repeat entry), bgzipped.
write_repeatmasker_fa_gz() {
    printf ">repeat_placeholder#Simple_repeat\nAAAAAAAAAAAAAAAAAAAA\n" | "${BGZIP}" -c > "$1"
}

# ---------------------------------------------------------------------------
# Steps
# ---------------------------------------------------------------------------

stage_genome_and_annotations() {
    log "[GRCh37] staging genome + annotations from sarek branch"
    local g="${REF_ROOT}/genome"
    local a="${REF_ROOT}/annotations"
    mkdir -p "${g}" "${a}"

    fetch "${SAREK_RAW}/reference/human_g1k_v37_decoy.small.fasta" "${g}/human_g1k_v37_decoy.fasta"
    "${SAMTOOLS}" faidx "${g}/human_g1k_v37_decoy.fasta"
    "${SAMTOOLS}" dict "${g}/human_g1k_v37_decoy.fasta" > "${g}/human_g1k_v37_decoy.dict"

    fetch "${SAREK_RAW}/reference/dbsnp_138.b37.small.vcf.gz"     "${a}/dbsnp_138.b37.vcf.gz"
    fetch "${SAREK_RAW}/reference/dbsnp_138.b37.small.vcf.gz.tbi" "${a}/dbsnp_138.b37.vcf.gz.tbi"
    fetch "${SAREK_RAW}/reference/gnomAD.r2.1.1.GRCh37.small.PASS.AC.AF.only.vcf.gz" \
        "${a}/af-only-gnomad.raw.sites.vcf.gz"
    fetch "${SAREK_RAW}/reference/gnomAD.r2.1.1.GRCh37.small.PASS.AC.AF.only.vcf.gz.tbi" \
        "${a}/af-only-gnomad.raw.sites.vcf.gz.tbi"
}

synthesize_hmfdata() {
    log "[GRCh37] synthesizing HMF/SAGE resources"
    local fai="$1" dir="${REF_ROOT}/hmfdata"
    mkdir -p "${dir}"

    write_empty_vcf_gz "${fai}" "${dir}/KnownHotspots.somatic.37.vcf.gz"
    write_empty_sage_pon_tsv_gz "${dir}/SageGermlinePon.1000x.37.tsv.gz"
    write_singleton_bed_gz \
        "${dir}/NA12878_GIAB_highconf_IllFB-IllGATKHC-CG-Ion-Solid_ALLCHROM_v3.2.2_highconf.bed.gz" \
        "${ANCHOR_CHROM}" "${ANCHOR_START}" "${ANCHOR_END}" "highconf_placeholder"
}

synthesize_gridss() {
    log "[GRCh37] synthesizing GRIDSS resources"
    local dir="${REF_ROOT}/gridss"
    mkdir -p "${dir}"
    # gridss.properties is hand-maintained and left untouched.

    write_singleton_sgl_pon_gz "${dir}/sgl_pon.37.bed.gz" "${ANCHOR_CHROM}" "${ANCHOR_START}" "${ANCHOR_END}"
    bedpe_line "${ANCHOR_CHROM}" "${ANCHOR_START}" | "${BGZIP}" -c > "${dir}/sv_pon.37.bedpe.gz"
    bedpe_line "${ANCHOR_CHROM}" "${ANCHOR_START}" > "${dir}/known_fusions.37.bedpe"
    write_repeatmasker_fa_gz "${dir}/repeat_mask_data.37.fa.gz"
}

build_gridss_index() {
    log "[GRCh37] building GRIDSS BWA index"
    local fasta="$1"
    local work="${STAGING}/gridss_index"
    local idx_fasta="${work}/$(basename "${fasta}")"

    rm -rf "${work}"
    mkdir -p "${work}"
    cp "${fasta}" "${idx_fasta}"
    cp "${fasta}.fai" "${idx_fasta}.fai"
    "${BWA}" index "${idx_fasta}" 2>/dev/null
    # gridsscache + .img are generated on first GRIDSS run; ship empty placeholders.
    : > "${idx_fasta}.gridsscache"
    : > "${idx_fasta}.img"
    tar -czf "${REF_ROOT}/gridss_index.tar.gz" -C "${STAGING}" gridss_index
    rm -rf "${work}"
}

generate_targets() {
    log "[GRCh37] generating slopped targets"
    local fasta="$1" dir="${REF_ROOT}/targets"
    local base_bed="${STAGING}/test_panel.targets.bed"
    local slop_bed="${dir}/test_panel.targets.slopped20.bed"
    mkdir -p "${dir}"

    write_singleton_bed "${base_bed}" "${ANCHOR_CHROM}" "${ANCHOR_START}" "${ANCHOR_END}" "${ANCHOR_GENE}"
    "${BEDTOOLS}" slop -i "${base_bed}" -g "${fasta}.fai" -b 20 > "${slop_bed}"
    # interval_list: 1-based, inclusive end.
    {
        "${SAMTOOLS}" dict "${fasta}" | grep -E '^@(HD|SQ)'
        awk -v OFS='\t' '{ print $1, $2+1, $3, "+", $4 }' "${slop_bed}"
    } > "${dir}/test_panel.targets.slopped20.interval_list"
}

stage_fastqs() {
    log "[FASTQ] staging sarek tiny tumor/normal FASTQs"
    local n="${TEST_ROOT}/fastqs/GRCh37/normal"
    local t="${TEST_ROOT}/fastqs/GRCh37/tumor"
    mkdir -p "${n}" "${t}"
    for lane in L001 L002; do
        for r in R1 R2; do
            fetch "${SAREK_RAW}/testdata/tiny/normal/tiny_n_${lane}_${r}_xxx.fastq.gz" \
                "${n}/tiny_n_${lane}_${r}_xxx.fastq.gz"
            fetch "${SAREK_RAW}/testdata/tiny/tumor/tiny_t_${lane}_${r}_xxx.fastq.gz" \
                "${t}/tiny_t_${lane}_${r}_xxx.fastq.gz"
        done
    done
}

write_samplesheet() {
    log "[CSV] writing samplesheet_grch37.csv"
    local csv_dir="${TEST_ROOT}/csv"
    local fq="${TESTDATA_RAW}/testdata/fastqs/GRCh37"
    mkdir -p "${csv_dir}"

    cat > "${csv_dir}/samplesheet_grch37.csv" <<EOF
case_id,sample_name,sample_type,lane,fastq_1,fastq_2,bam
TEST,TUMOR,tumor,L001,${fq}/tumor/tiny_t_L001_R1_xxx.fastq.gz,${fq}/tumor/tiny_t_L001_R2_xxx.fastq.gz,
TEST,TUMOR,tumor,L002,${fq}/tumor/tiny_t_L002_R1_xxx.fastq.gz,${fq}/tumor/tiny_t_L002_R2_xxx.fastq.gz,
TEST,NORMAL,normal,L001,${fq}/normal/tiny_n_L001_R1_xxx.fastq.gz,${fq}/normal/tiny_n_L001_R2_xxx.fastq.gz,
TEST,NORMAL,normal,L002,${fq}/normal/tiny_n_L002_R1_xxx.fastq.gz,${fq}/normal/tiny_n_L002_R2_xxx.fastq.gz,
EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    require_tools
    mkdir -p "${STAGING}"

    local fasta="${REF_ROOT}/genome/human_g1k_v37_decoy.fasta"

    stage_genome_and_annotations
    synthesize_hmfdata "${fasta}.fai"
    synthesize_gridss
    build_gridss_index "${fasta}"
    generate_targets "${fasta}"
    stage_fastqs
    write_samplesheet

    log "DONE. Review with 'git -C ${REPO_ROOT} status' and 'git -C ${REPO_ROOT} diff --stat'."
}

main "$@"
