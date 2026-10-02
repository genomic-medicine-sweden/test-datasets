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
# INFO fields retained (17), as candidates for a mito --custom annotation (not wired into nallo yet):
#   hap_defining_variant, AN, AC_hom, AC_het, AF_hom, AF_het, max_hl,
#   hap_AN, hap_AC_hom, hap_AC_het, hap_AF_hom, hap_AF_het, hapmax_AF_hom, hapmax_AF_het,
#   mitotip_score, pon_ml_probability_of_pathogenicity, common_low_heteroplasmy
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

# INFO fields to keep (all other INFO fields are removed)
KEEP="INFO/hap_defining_variant,INFO/AN,INFO/AC_hom,INFO/AC_het,INFO/AF_hom,INFO/AF_het,INFO/max_hl"
KEEP="$KEEP,INFO/hap_AN,INFO/hap_AC_hom,INFO/hap_AC_het,INFO/hap_AF_hom,INFO/hap_AF_het"
KEEP="$KEEP,INFO/hapmax_AF_hom,INFO/hapmax_AF_het"
KEEP="$KEEP,INFO/mitotip_score,INFO/pon_ml_probability_of_pathogenicity,INFO/common_low_heteroplasmy"

echo "Subsetting to $(bcftools view -H "$INPUT_VCF" | wc -l) positions and stripping unused INFO fields..."
bcftools view -r "$REGIONS" "$GNOMAD_RAW" | bcftools annotate -x "^$KEEP" -O z -o "$OUTPUT_VCF"

tabix -p vcf "$OUTPUT_VCF"

echo "Done."
echo "Variants: $(bcftools view -H "$OUTPUT_VCF" | wc -l)"
ls -lh "$OUTPUT_VCF" "${OUTPUT_VCF}.tbi"
