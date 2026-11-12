#!/usr/bin/env python3
"""
Build a tiny MSIsensor2 models directory for a small test reference.

MSIsensor2 models dir layout (reverse-engineered from models_b37_HumanG1Kv37):
  * 1030c0aa35ca5c263daeae866ad18632 : TSV site list (fixed file name)
  * md5("<contig>_<location>")       : one XGBoost model per site

Site-list columns: chromosome, location (0-based repeat start), repeat_unit_length,
repeat_unit_binary, repeat_times, left/right_flank_binary (5 bp, base-4 A0 C1 G2 T3),
repeat_unit_bases, left/right_flank_bases.

Per-site models are copied from a donor model of the official set; they are only used
to make the command run on test data, so the MSI calls are meaningless.

Usage:
  make_msisensor2_test_models.py --fasta ref.fa --region 1:132680-139758 \
      --donor-models models_b37_HumanG1Kv37 --outdir models_test [--min-repeat 5]
"""
import argparse
import hashlib
import re
import shutil
import subprocess
from pathlib import Path

SITE_LIST = "1030c0aa35ca5c263daeae866ad18632"
HEADER = [
    "chromosome", "location", "repeat_unit_length", "repeat_unit_binary", "repeat_times",
    "left_flank_binary", "right_flank_binary", "repeat_unit_bases", "left_flank_bases",
    "right_flank_bases",
]
BASE4 = {"A": 0, "C": 1, "G": 2, "T": 3}
FLANK = 5


def encode(bases):
    value = 0
    for b in bases:
        value = value * 4 + BASE4[b]
    return value


def model_name(contig, location):
    return hashlib.md5(f"{contig}_{location}".encode()).hexdigest()


def fetch(fasta, region):
    out = subprocess.run(["samtools", "faidx", fasta, region], check=True, capture_output=True, text=True)
    return "".join(out.stdout.splitlines()[1:]).upper()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fasta", required=True)
    ap.add_argument("--region", required=True, action="append", help="contig:start-end (1-based), repeatable")
    ap.add_argument("--donor-models", required=True, type=Path)
    ap.add_argument("--outdir", required=True, type=Path)
    ap.add_argument("--min-repeat", type=int, default=5)
    args = ap.parse_args()

    donor_sites = (args.donor_models / SITE_LIST).read_text().splitlines()[1:]
    # Donor: first homopolymer site in the official set
    donor = next(r.split("\t") for r in donor_sites if r.split("\t")[2] == "1")
    donor_model = args.donor_models / model_name(donor[0], donor[1])

    args.outdir.mkdir(parents=True, exist_ok=True)
    rows = []
    for region in args.region:
        contig, span = region.split(":")
        start = int(span.split("-")[0])
        seq = fetch(args.fasta, region)
        pattern = r"(A{n,}|C{n,}|G{n,}|T{n,})".replace("n", str(args.min_repeat))
        for m in re.finditer(pattern, seq):
            left = seq[m.start() - FLANK:m.start()]
            right = seq[m.end():m.end() + FLANK]
            if len(left) < FLANK or len(right) < FLANK or "N" in left + right:
                continue
            location = start + m.start() - 1  # 0-based repeat start
            unit = m.group()[0]
            rows.append([contig, location, 1, BASE4[unit], len(m.group()),
                         encode(left), encode(right), unit, left, right])
            shutil.copyfile(donor_model, args.outdir / model_name(contig, location))

    with open(args.outdir / SITE_LIST, "w") as fh:
        fh.write("\t".join(HEADER) + "\n")
        for r in rows:
            fh.write("\t".join(map(str, r)) + "\n")
    print(f"Wrote {len(rows)} sites to {args.outdir}")


if __name__ == "__main__":
    main()
