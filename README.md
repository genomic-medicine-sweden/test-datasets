# test-datasets: `genomic-medicine-sweden/metaval`

This branch contains test data to be used for automated testing with the [genomic-medicine-sweden/metaval](https://github.com/genomic-medicine-sweden/meta-val) pipeline.

## Content of this repository

- `samplesheet.csv`: an input samplesheet.csv.
- `samplesheet_v1.csv`: an input samplesheet contains three more meta columns: `library_type`, `is_ntc` and `batch`
- `‎all_phages_taxids_YYMMDD.txt`: a list of phages taxid to be excluded from downstream analysis. This file contains species that have phages in their name,viral taxids that are bacterial hosts, all taxids that belong to the class Caudoviricetes and the contaminant Equine infectious anemia virus with taxid 11665
- `phages_taxid_test.txt`: a list of phages taxid to be excluded from running test configs.


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


### For creating the phage list: ###

1. Extract accession, species and host

```
// Download the AllNucleMetadata and make sure you have csvtk installed in a conda environment
wget https://ftp.ncbi.nlm.nih.gov/genomes/Viruses/AllNuclMetadata/AllNuclMetadata.csv.gz
gunzip AllNuclMetadata.csv.gz

csvtk cut -f 1,7,19 AllNuclMetadata.csv > extracted_info
```

2. Extract unique hosts

```
csvtk cut -f 3 extracted_info | tail -n +2 | sed '/^$/d' | sort -u > hosts.txt
```

3. Convert names to taxids

```
//Make sure to have taxonkid installed in a conda env
taxonkit name2taxid hosts.txt > host_taxids.txt
```

4. Get lineages for the hosts

```
cut -f2 host_taxids.txt | grep -E '^[0-9]+$' | taxonkit lineage > host_lineages.txt
```

5. Keep bacterial hosts and get their taxids:

```
grep 'Bacteria' host_lineages.txt > extracted_bacterial_hosts.txt
cut -f1 extracted_bacterial_hosts.txt | sort -n -u > bacterial_host_taxids.txt
```

6. Map the bacterial taxids back to names

```
awk -F'\t' '
NR==FNR {b[$1]=1; next}
($2 in b) {print $1}
' bacterial_host_taxids.txt host_taxids.txt \
> bacterial_host_names.txt
```

7. Find the viruses that are associated with bacterial hosts

```
awk -F',' '
NR==FNR {b[$0]=1; next}
FNR==1 {next}
($3 in b) {print}
' bacterial_host_names.txt extracted_info \
> viral_bacterial_hosts.csv
```

8. Extract the viral accessions

// Make sure you have NCBI datasets installed
```
cut -d',' -f1 viral_bacterial_hosts.csv > viral_accessions.txt
datasets summary virus genome accession --inputfile viral_accessions.txt > viral_accessions.jsonl
```

9. Extract the accession and viral taxids

// Make sure jq is installed

```
jq -r '
    [
        .reports[]
        | [
            .accession,
            .virus.tax_id
        ]
    ][]
    | @tsv
' viral_accessions.jsonl > viral_accessions_taxids.txt
```

10. Keep only the taxids

```
awk '{print $NF}' viral_accessions_taxids.txt > bacterial_host_viral_taxids.txt
```

After you have added any additional taxids that need to be excluded, rename the file to this format: `all_phages_taxids_YYMMDD.txt`
