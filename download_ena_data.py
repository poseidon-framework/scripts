#!/usr/bin/env python3

import sys
import argparse
import os
import yaml

parser = argparse.ArgumentParser(
    prog = 'download_ena_data',
    description = 'This script downloads raw FASTQ data from the ENA, using '
                  'links to the raw data and metadata provided by the Poseidon '
                  'sequencingSourceFile')

parser.add_argument('-d', '--poseidon_package_dir', metavar="<DIR>", required=True, help="A base directory with Poseidon packages ")
parser.add_argument('-o', '--output_dir', metavar="<DIR>", required=True, help="The output directory for the FASTQ data")
parser.add_argument('--dry_run', action='store_true', help="Only list the download commands, but don't do anything")

def read_ena_table(file_name):
    l = file_name.readlines()
    headers = l[0].split()
    return list(map(lambda row: dict(zip(headers, row.split())), l[1:]))

args = parser.parse_args()

print("Scanning poseidon packages for sequencingSource files", file=sys.stderr)

for root, dirs, files in os.walk(args.poseidon_package_dir):
    for file_name in files:
        if file_name == "POSEIDON.yml":
            s = open(os.path.join(root, file_name), 'r')
            pac = yaml.load(s, Loader=yaml.CLoader)
            if 'sequencingSourceFile' in pac:
                source_file = os.path.join(root, pac['sequencingSourceFile'])
                print("Found Sequencing Source File: ", source_file, file=sys.stderr)
                pac_dir_name = os.path.basename(root)
                odir = os.path.join(args.output_dir, pac_dir_name)
                os.makedirs(odir, exist_ok=True)
                with open(source_file, 'r') as f: 
                    ena_entries = read_ena_table(f)
                    print(ena_entries)

