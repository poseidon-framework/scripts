# Repository of scripts around Poseidon

## `poseidon_sdag_rsync.sh`

This script was initially used to copy our department-level repository to our Cloud server. Not used anymore, but would like to keep for reference. This script makes use of `exclude_patterns.txt`.

## `poseidon_server_nextcloud_backup.sh`

A script to be run on any computer to copy the entire repository on our Cloudserver to that computer. In my case the target directory is synced onto Nextcloud to have maximum backup safety.

## `make-repo-directry.py` 

Old script to zip all packages for the server. Don't need this anymore, since the HTTP server program is now capable of zipping automatically.

## `get_ena_table.py`

This script can be used like this:

    ./get_ena_table.py PRJEB39316 -o test.tsv

which downloads a TSV table with meta-info including URLS to download fastq-files in the specified output file (here `test.tsv`).