"""Expose real XCTest outcomes as GitHub annotations while retaining the raw log."""
import re
import sys

def escaped(value):
    return value.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')

for line in sys.stdin:
    sys.stdout.write(line)
    sys.stdout.flush()
    if re.search(r"Test Case '.+' (passed|failed)", line):
        level = 'error' if "' failed" in line else 'notice'
        print(f'::{level} title=XCTest result::{escaped(line.strip())}', flush=True)
    elif re.search(r'\berror: ', line):
        print(f'::error title=Xcode::{escaped(line.strip()[:2000])}', flush=True)
