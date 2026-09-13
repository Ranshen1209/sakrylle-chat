#!/usr/bin/env python3
"""Reject mismatched tags and existing releases before any asset upload."""
import json
import os
import re
import subprocess
import urllib.error
import urllib.request
from pathlib import Path

version = re.search(r'^version: (.+)$', Path('pubspec.yaml').read_text(), re.M)[1]
tag = os.environ['RELEASE_TAG']
if tag != f'v{version}':
    raise SystemExit(f'Release tag must match application version: v{version}')
sha = subprocess.check_output(['git', 'rev-parse', f'refs/tags/{tag}^{{commit}}'], text=True).strip()
if sha != os.environ['GITHUB_SHA']:
    raise SystemExit('Release tag does not point to the workflow commit')
request = urllib.request.Request(
    f"https://api.github.com/repos/{os.environ['GITHUB_REPOSITORY']}/releases/tags/{tag}",
    headers={'Authorization': f"Bearer {os.environ['GH_TOKEN']}", 'Accept': 'application/vnd.github+json'},
)
try:
    with urllib.request.urlopen(request) as response:
        json.load(response)
except urllib.error.HTTPError as error:
    if error.code != 404:
        raise
else:
    raise SystemExit('Release already exists; refusing to overwrite published or draft assets')
print(f'Release preflight passed: {tag} at {sha}')
