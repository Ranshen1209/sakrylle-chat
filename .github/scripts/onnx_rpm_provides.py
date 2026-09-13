#!/usr/bin/env python3
"""Describe the bundled ONNX ABI that RPM misses due to its version-base name.

sherpa_onnx_linux's SONAME is libonnxruntime.so, but its ELF version-definition
base is libonnxruntime.so.1.17.1. RPM uses the latter for versioned Provides while
Sherpa requires the former. Derive the alias from the actual exported API;
never suppress automatic dependency checking or invent an absent capability.
"""
import os
import re
import subprocess
import sys

library = sys.argv[1]
readelf = os.environ.get('READELF', 'readelf')

def inspect(*args):
    return subprocess.check_output(
        [readelf, *args, library], text=True, env={**os.environ, 'LC_ALL': 'C'}
    )

header = inspect('-h')
dynamic = inspect('-d')
symbols = inspect('--dyn-syms', '--wide')
if not re.search(r'Class:\s+ELF64\b', header):
    raise SystemExit('Expected the bundled 64-bit ONNX library')
if not re.search(r'\(SONAME\).*\[libonnxruntime\.so\]', dynamic):
    raise SystemExit('Unexpected ONNX SONAME; recheck RPM metadata')
match = re.search(
    r'\bFUNC\s+GLOBAL\s+DEFAULT\s+\d+\s+OrtGetApiBase@@(VERS_[0-9.]+)\b',
    symbols,
)
if not match:
    raise SystemExit('Bundled library does not export a versioned OrtGetApiBase')
print(f'libonnxruntime.so({match[1]})(64bit)')
