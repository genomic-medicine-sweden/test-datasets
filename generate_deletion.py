import sys
import argparse
import pysam


def main():
    parser = argparse.ArgumentParser(
        description="Introduce a synthetic deletion in reads (BAM → FASTQ)"
    )
    parser.add_argument("--input", required=True, help="Input BAM file")
    parser.add_argument(
        "--start",
        type=int,
        required=True,
        help="Deletion start (0-based, inclusive)"
    )
    parser.add_argument(
        "--end",
        type=int,
        required=True,
        help="Deletion end (0-based, exclusive)"
    )
    parser.add_argument(
        "--contig",
        default="chrM",
        help="Reference contig (default: chrM)"
    )
    # The BAM header can't be relied on to identify PacBio input (the test BAMs have no RG PL field)
    parser.add_argument(
        "--platform",
        choices=["pacbio", "ont"],
        help="Sequencing platform; qs/qe tag checks only apply to pacbio"
    )
    parser.add_argument(
        "--fill-missing-qs-qe",
        action="store_true",
        help="PacBio only: add qs=0 and qe=qs+read length to reads missing these tags"
    )

    args = parser.parse_args()

    if args.start >= args.end:
        raise ValueError("start must be < end")
    if args.fill_missing_qs_qe and args.platform != "pacbio":
        parser.error("--fill-missing-qs-qe requires --platform pacbio")

    is_pacbio = args.platform == "pacbio"
    n_reads = 0
    n_missing_qs_qe = 0

    in_bam = pysam.AlignmentFile(args.input, "rb")
    out = sys.stdout

    for read in in_bam.fetch(args.contig):

        if read.is_unmapped:
            continue

        seq = read.query_sequence
        qual = read.qual

        if seq is None or qual is None:
            continue

        ref_pos = read.reference_start
        read_end = read.reference_end

        # Extract RG tag if present
        rg = read.get_tag("RG") if read.has_tag("RG") else "NA"

        # Preserve original FASTQ suffixes for paired reads
        if read.is_read1:
            read_suffix = "/1"
        elif read.is_read2:
            read_suffix = "/2"
        else:
            read_suffix = ""

        new_seq = seq
        new_qual = qual

        # If there is an overlap → splice out deletion; If there is no overlap, keep the read as is and add the tags
        if read_end >= args.start and ref_pos <= args.end:
            left = max(0, args.start - ref_pos)
            right = max(0, read_end - args.end)

            if right > 0:
                new_seq = seq[:left] + seq[-right:]
                new_qual = qual[:left] + qual[-right:]
            else:
                new_seq = seq[:left]
                new_qual = qual[:left]
        
        # Add RG into FASTQ header
        header = f"{read.query_name}{read_suffix} RG:Z:{rg}"
        qs = read.get_tag("qs") if read.has_tag("qs") else None
        # Keep the original query start and account for removed bases.
        qe = read.get_tag("qe") - (len(seq) - len(new_seq)) if read.has_tag("qe") else None

        # pbmm2 treats PacBio reads without qs/qe as empty and leaves them unmapped
        if is_pacbio and (qs is None or qe is None):
            n_missing_qs_qe += 1
            if args.fill_missing_qs_qe:
                # Synthetic values: assume the read is a whole, unsplit read
                if qs is None:
                    qs = 0
                if qe is None:
                    qe = qs + len(new_seq)

        if qs is not None:
            header += f"\tqs:i:{qs}"
        if qe is not None:
            header += f"\tqe:i:{qe}"

        out.write(f"@{header}\n{new_seq}\n+\n{new_qual}\n")
        n_reads += 1

    in_bam.close()

    # One summary line on stderr so stdout stays a clean FASTQ stream
    if n_missing_qs_qe:
        if args.fill_missing_qs_qe:
            print(
                f"Filled missing qs/qe tags in {n_missing_qs_qe} of {n_reads} PacBio reads "
                "(qs=0, qe=qs+read length).",
                file=sys.stderr,
            )
        else:
            print(
                f"Warning: {n_missing_qs_qe} of {n_reads} PacBio reads are missing qs and/or qe tags; "
                "some aligners (e.g. pbmm2) may leave these reads unmapped. "
                "Use --fill-missing-qs-qe to add them.",
                file=sys.stderr,
            )


if __name__ == "__main__":
    main()