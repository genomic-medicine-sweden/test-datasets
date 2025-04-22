# test-datasets: `genomic-medicine-sweden/gms_16S`

This branch contains test data to be used for automated testing with the [genomic-medicine-sweden/gms_16S](https://github.com/genomic-medicine-sweden/gms_16S) pipeline.

## Content of this repository
The fastq.gz files in this repository comes from nanopore sequencing of ATCC-MSA-2002 which is a mixture of 20 bacterial species.  
- **testdata/**
  - `medium_Mock_dil_1_2_BC1.fastq.gz`: Contains 100 reads
  - `medium_Mock_dil_1_2_BC3.fastq.gz`: Contains 100 reads
  - `Mock_dil_1_2_BC1.fastq.gz`: Contains 14084 reads. Original sample for medium_Mock_dil_1_2_BC1.fastq.gz
  - `Mock_dil_1_2_BC3.fastq.gz`: Contains 34943 reads. Original sample for medium_Mock_dil_1_2_BC3.fastq.gz
  - `small_test_data2.fastq.gz`: Contains 3 reads. (Original sample is not available in this repo) Identical to small_test_data3.fastq.gz
  - `small_test_data3.fastq.gz`: Contains 3 reads. (original sample is not available in this repo). Identical to small_test_data2.fastq.gz

