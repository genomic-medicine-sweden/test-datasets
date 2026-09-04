# test-datasets: `genomic-medicine-sweden/metaval`

This branch contains test data to be used for automated testing with the [genomic-medicine-sweden/metaval](https://github.com/genomic-medicine-sweden/meta-val) pipeline.

## Content of this repository

- `samplesheet.csv`: an input samplesheet.csv.
- `samplesheet_v1.csv`: an input samplesheet contains three more meta columns: `library_type`, `is_ntc` and `batch`
- `all_phages_taxid.txt`: a list of phages taxid to be excluded from downstream analysis. This file contains species that have phages in their name,viral taxids that are bacterial hosts, all taxids that belong to the class Caudoviricetes and the contaminant Equine infectious anemia virus with taxid 11665
- `phages_taxid_test.txt`: a list of phages taxid to be excluded from running test configs.

# For the species with `phage` in their name:

```sh
conda install bioconda::taxonkit
# Download NCBI taxonomy database and make sure that is the same used as in taxpasta in taxprofiler
wget https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
tar -xzf taxdump.tar.gz

#Extract taxid and species name
export TAXONKIT_DB="$PWD"
taxonkit list --ids 1 --show-name --show-rank --indent "" \
| awk '{name=$0; sub(/^[^ ]+ \[[^]]+\] /,"",name); print $1"\t"name}' \
> taxid_name_allranks.tsv

#Use grep and sed to pick the taxid of species name containing phage (case insensitive)
grep -i 'phage' taxid_name_allranks.tsv | sed 's/\t.*//' > phage_taxids.txt
```

# For viruses with bacteria as host:

```sh
conda install conda-forge::csvkit
# Download and gunzip the metadata for all viral nucleotide records

wget https://ftp.ncbi.nlm.nih.gov/genomes/Viruses/AllNuclMetadata/AllNuclMetadata.csv.gz
gunzip AllNuclMetadata.csv.gz

# Extract host names
csvcut -c Host AllNuclMetadata.csv \
| tail -n +2 \
| grep -v '^""$' \
| sort -u > hosts.txt

# Map host names to taxids
taxonkit name2taxid hosts.txt > host_taxids.tsv

# Get the lineage of each host
cut -f2 host_taxids.tsv \
| taxonkit lineage \
| taxonkit reformat

# Identify bacterial hosts

cut -f2 host_taxids.tsv \
| taxonkit lineage \
| grep -E 'Bacteria|'
```

# For taxids that belong the class Caudoviricetes
```sh
taxonkit list --ids 2731618 | sed 's/^[[:space:]]*//' > Caudoviricetes_taxids.txt
```

Concatenate all the three files together.

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
