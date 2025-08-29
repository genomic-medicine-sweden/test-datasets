# test-datasets: `genomic-medicine-sweden/metaval`

This branch contains test data to be used for automated testing with the [genomic-medicine-sweden/metaval](https://github.com/genomic-medicine-sweden/meta-val) pipeline.

## Content of this repository

- `samplesheet.csv`: an input samplesheet.csv.

- **blastdb/**

  - `blastn/blastn_testdb.tar.gz`: a blastn test database.
  - `blastx/diamond_testdb.dmnd`: a blastx (diamond) test database.

- **reference/**

  - `reference.fasta`: a FASTA file containing a list of pathogen genomes.
  - `accession2taxid,map`: a map file containing genome accessions of pathogens and their corresponding taxonomic IDs

- **testdata/**

  - `*fastq.gz`: FASTQ files, which can be raw FASTQ files, filtered FASTQ files, or FASTQ files after host removal.
  - `*kraken2.report.txt`: `Kraken2` report files containing stats about classified and not classified reads.
  - `*kraken2.classifiedreads.txt`: `Kraken2` result files containing the taxonomic assignment of each input read.
  - `kraken2_k2_pluspf.tsv`: Standardized `Kraken2` taxonomic profiles for all samples.
  - `*centrifuge.txt`: `Centrifuge` report files containing kraken-style report from `Centrifuge` output files.
  - `*centrifuge.results.txt`: `Centrifuge` result files containing classification results.
  - `centrifuge_p_compressed+h+v.tsv`: Standardized `Centrifuge` taxonomic profiles for all samples.
  - `*_diamond.diamond.tsv`: `DIAMOND` classification results containing the taxonomic classification of hits.
  - `diamond_diamond.tsv`: Standardized `DIAMOND` taxonomic profiles for all samples.

- **genomesdb/**
  - `taxid2genome.map`: A map file containing taxonomic IDs and their corresponding genome files
  - `genomes/`: Genome files listed in the map file.
