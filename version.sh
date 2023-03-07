#!/usr/bin/env bash
set -e

# grep the version from the Dockerfile
grep -E 'LABEL version=' Dockerfile | cut -d= -f2 | tr -d '"'
