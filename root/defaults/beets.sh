#!/usr/bin/env bash
# shellcheck shell=bash
#
# beets music tagger - post-processing script
#
# Author: Rich Manton (overbyrn)
# Date: 29-04-13
#
# $1 - Fullpath of directory to be processed.
# $7 - Status of post processing. 0 = OK, 1 = failed verification,
#      2 = failed unpack, 3 = 1+2

if [ -n "${7:-}" ] && [ "$7" -gt 0 ]; then
  echo "post-processing failed, bypassing script"
  exit 1
fi

echo "--------------------------"
printf %b "$(date)\n"
echo "Starting beets.sh for $(basename "$1")"

export BEETSDIR=/config
export FPCALC="${FPCALC:-/usr/bin/fpcalc}"
beet -v import -q "$1"
