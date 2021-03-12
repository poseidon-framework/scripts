#!/usr/bin/env bash

rsync -avzP --exclude-from=exclude_patterns.txt /projects1/poseidon/repo/modern/ gwdg:poseidon-repos/data_modern

rsync -avzP --exclude-from=exclude_patterns.txt /projects1/poseidon/repo/ancient/ gwdg:poseidon-repos/data_ancient
