#!/usr/bin/env bash
set -xeuo pipefail

_CURRENT="$(date +%Y%m%d%H%M%S).sif"

cd "$HOME/nyx/guest"
singularity build --fakeroot --force "$_CURRENT" ../Singularity
ln -fsT "./$_CURRENT" "./latest"

# Visible exit
exit 0

