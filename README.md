# test-datasets: `genomic-medicine-sweden/metaval`

This branch contains test data to be used for automated testing with the [genomic-medicine-sweden/metaval](https://github.com/genomic-medicine-sweden/meta-val) pipeline.

## Content of this repository

- `samplesheet.csv`: an input samplesheet.csv.
- `samplesheet_v1.csv`: an input samplesheet contains three more meta columns: `library_type`, `is_ntc` and `batch`  
- `phages_taxid.txt`: a list of phages taxid to be excluded from downstream analysis. This file was prepared using [taxonkit](https://bioinf.shenwei.me/taxonkit/)
```sh
conda install bioconda::taxonkit
# Download NCBI taxonomy database
wget https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
tar -xzf taxdump.tar.gz
export TAXONKIT_DB="$PWD"
# Most of phages from our lab belong to the class Caudoviricetes
echo Caudoviricetes | taxonkit name2taxid | taxonkit lineage -i 2 -r -L
taxonkit list --ids 2731619 --indent "" > phages_taxid.txt
```
- **blastdb/**

  - `blastn/blastn_testdb.tar.gz`: a blastn test database.
  - `blastx/diamond_testdb.dmnd`: a blastx (diamond) test database.

- **reference/**

  - `reference.fasta.gz`: a compressed FASTA file containing a list of pathogen genomes.
  - `accession2taxid,map`: a map file containing genome accessions of pathogens, corresponding taxonomic IDs and organism names.

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
  - `taxid2genome.map`: A map file containing taxonomic IDs, organism names and corresponding genome files.
  - `genomes/`: Genome files listed in the map file.
