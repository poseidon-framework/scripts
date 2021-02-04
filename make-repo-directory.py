#!/usr/bin/env python3

import os
import yaml
import json
import sys
import zipfile

dir_ = "/Users/schiffels/poseidon/repo"
reldir = "/Users/schiffels/poseidon/repo"
outJSON = "out.json"

repo_dir = []
for path, dirs, files in os.walk(dir_):
  for file_ in files:
    if file_ == "POSEIDON.yml":
      print("Processing", path, file=sys.stderr)
      zipFN = path + ".zip"
      with zipfile.ZipFile(zipFN, 'w') as zipF:
        for f in files:
          zipF.write(os.path.join(path, f), arcname=f)

      with open(os.path.join(path, file_), 'r') as stream:
        yml = yaml.safe_load(stream)
      package_obj = {
        'path' : os.path.relpath(path, start=reldir),
        'pos_yaml' : os.path.relpath(os.path.join(path, file_), start=reldir),
        'title' : yml['title'],
        'zip_file' : zipFN
      }
      repo_dir.append(package_obj)

with open(outJSON, 'w') as f:
  print(json.dumps(repo_dir), file=f)

