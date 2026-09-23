#!/usr/bin/env bash
# Generate a minimal gnomAD MT VCF fixture for nallo mito VEP annotation tests.
#
# Input:  HG002_deepvariant_norm_chrM.vcf.gz  (must exist in the current directory)
# Output: gnomad_mt.vcf.gz + .tbi
#
# Positions are taken from the input VCF so the fixture covers exactly the alleles
# that appear in the chrM test sample. All other gnomAD MT alleles at those positions
# are also kept (needed for VEP --custom exact matching on multi-allelic sites).
#
# INFO fields retained (14): those used by extra_vep_options_snv_mito --custom in nallo.
#   hap_defining_variant, AN, AC_hom, AC_het, AF_hom, AF_het, max_hl,
#   hap_AN, hap_AC_hom, hap_AC_het, hap_AF_hom, hap_AF_het, hapmax_AF_hom, hapmax_AF_het
#
# Requirements: bcftools >= 1.17, tabix, curl

set -euo pipefail

INPUT_VCF="HG002_deepvariant_norm_chrM.vcf.gz"
GNOMAD_URL="https://storage.googleapis.com/gcp-public-data--gnomad/release/3.1/vcf/genomes/gnomad.genomes.v3.1.sites.chrM.vcf.bgz"
GNOMAD_RAW="gnomad.genomes.v3.1.sites.chrM.vcf.bgz"
OUTPUT_VCF="gnomad_mt_test_data.vcf.gz"

if [ ! -f "$INPUT_VCF" ]; then
    echo "ERROR: $INPUT_VCF not found in current directory" >&2
    exit 1
fi

# Download gnomAD v3.1 chrM
echo "Downloading gnomAD v3.1 chrM VCF..."
curl -L -o "$GNOMAD_RAW" "$GNOMAD_URL"
curl -L -o "${GNOMAD_RAW}.tbi" "${GNOMAD_URL}.tbi"

# Extract regions from input VCF (one region per variant position)
REGIONS=$(bcftools view -H "$INPUT_VCF" | awk '{print $1":"$2"-"$2}' | tr '\n' ',' | sed 's/,$//')

# INFO fields to drop (everything except the 14 we keep)
DROP="INFO/age_hist_het_bin_freq,INFO/age_hist_het_n_larger,INFO/age_hist_het_n_smaller"
DROP="$DROP,INFO/age_hist_hom_bin_freq,INFO/age_hist_hom_n_larger,INFO/age_hist_hom_n_smaller"
DROP="$DROP,INFO/base_qual_hist,INFO/contamination_hist,INFO/dp_hist_all_bin_freq"
DROP="$DROP,INFO/dp_hist_all_n_larger,INFO/dp_hist_alt_bin_freq,INFO/dp_hist_alt_n_larger"
DROP="$DROP,INFO/dp_mean,INFO/excluded_AC,INFO/faf_hapmax_hom,INFO/filters,INFO/hap_faf_hom"
DROP="$DROP,INFO/hap_hl_hist,INFO/heteroplasmy_below_min_het_threshold_hist,INFO/hl_hist"
DROP="$DROP,INFO/mq_mean,INFO/pop_AC_het,INFO/pop_AC_hom,INFO/pop_AF_het,INFO/pop_AF_hom"
DROP="$DROP,INFO/pop_AN,INFO/pop_hl_hist,INFO/position_hist,INFO/strand_bias_hist"
DROP="$DROP,INFO/tlod_mean,INFO/variant_collapsed,INFO/vep,INFO/weak_evidence_hist"

echo "Subsetting to $(bcftools view -H "$INPUT_VCF" | wc -l) positions and stripping unused INFO fields..."
bcftools view -r "$REGIONS" "$GNOMAD_RAW" |     bcftools annotate -x "$DROP" -O z -o "$OUTPUT_VCF"

tabix -p vcf "$OUTPUT_VCF"

echo "Done."
echo "Variants: $(bcftools view -H "$OUTPUT_VCF" | wc -l)"
ls -lh "$OUTPUT_VCF" "${OUTPUT_VCF}.tbi"
