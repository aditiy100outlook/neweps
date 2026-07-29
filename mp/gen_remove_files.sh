#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

trap ctrl_c INT
function ctrl_c() {
  find . -name '*_samplefile.txt' -type f -print0 | xargs -0 rm
}

printf "Generating and removing 10K files in local directory.\nSleep 30s each iteration.\n\nPress CTRL+C to quit."


while [[ 1 ]]; do
  for f in `seq 10000 20000`; do
    date > ${f}_samplefile.txt
  done

  sleep 30

  find . -name '*_samplefile.txt' -type f -print0 | xargs -0 rm
done
