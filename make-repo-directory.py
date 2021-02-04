#!/usr/bin/env python3

import os
import yaml
import json

dir_ = "/var/www/bioinf/htdocs/poseidon/repo"
outJSON = "/var/www/bioinf/htdocs/poseidon/package_dir.json"
outMD = "/var/www/bioinf/htdocs/poseidon/package_dir.md"

repo_dir = []
for path, dirs, files in os.walk(dir_):
  for file_ in files:
    if file_ == "POSEIDON.yml":
      with open(os.path.join(path, file_), 'r') as stream:
        yml = yaml.safe_load(stream)
      package_obj = {
        'path' : os.path.relpath(path, start=dir_),
        'pos_yaml' : os.path.relpath(os.path.join(path, file_), start=dir_),
        'title' : yml['title']
      }
      repo_dir.append(package_obj)

with open(outJSON, 'w') as f:
  print(json.dumps(repo_dir), file=f)

with open(outMD, 'w') as f:
  print("| Package | URL |", file=f)
  print("| ------- | --- |", file=f)
  for package_obj in repo_dir:
    print(f"| {package_obj['title']} | https://bioinf.eva.mpg.de/poseidon/repo/{package_obj['path']} |", file=f)
