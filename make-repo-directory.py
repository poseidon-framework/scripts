#!/usr/bin/env python3

import os
import yaml
import json
import sys
import zipfile

# dir_ = "/Users/schiffels/poseidon/repo"
# outJSON = "out.json"
# outHTML = 'index.html'
dir_ = "/var/www/bioinf/htdocs/poseidon/repo"
outJSON = "/var/www/bioinf/htdocs/poseidon/package_dir.json"
outHTML = "/var/www/bioinf/htdocs/poseidon/index.html"

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
        'path' : os.path.relpath(path, start=dir_),
        'pos_yaml' : os.path.relpath(os.path.join(path, file_), start=dir_),
        'title' : yml['title'],
        'description' : yml.get("description", "n/a"),
        "packageVersion" : yml.get("packageVersion", "n/a"),
        'zip_file' : zipFN
      }
      repo_dir.append(package_obj)

with open(outJSON, 'w') as f:
  print(json.dumps(repo_dir), file=f)

html_table = """
<tr>
  <th>Package Name</th>
  <th>Description</th>
  <th>Package Version</th>
  <th>Download</th>
</tr>
"""

for pck in repo_dir:
  html_table += f"""
<tr>
  <td>{pck['title']}</td>
  <td>{pck['description']}</td>
  <td>{pck['packageVersion']}</td>
  <td><a href=\"{os.path.relpath(pck['zip_file'], start="/var/www/bioinf/htdocs/poseidon")}\" download>{os.path.basename(pck['zip_file'])}</a></td>
</tr>
"""

with open(outHTML, 'w') as f:
  print(f"""
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Poseidon Package Repository</title>
  </head>
  <body>
    <h1>Poseidon Package Repository</h1>
    <table>
    {html_table}
    </table>
  </body>
</html>
""", file=f)
