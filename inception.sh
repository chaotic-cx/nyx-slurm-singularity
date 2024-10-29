#!/bin/bash

# Errors in this script are critical
set -euo pipefail

if [[ "$(hostname)" == "sms" ]] && [ -d /tmp/nyx/sandbox ]; then
  echo 'TO RUN INSIDE CONTROLLER WHERE A JOB EXISTS'
  exit 1
fi

# Preprare container working directories
export XDG_RUNTIME_DIR=/tmp/nyx/run

# Make sure sandbox has the temporary stuff
mkdir -p /tmp/nyx/sandbox/{tmp/nyx-wd,var/tmp,proc,sys}

# Starts the container and run nyx-build
exec singularity shell --writable --fakeroot --no-home --containall \
  -B '/dev/full:/dev/full' \
  -B "$HOME/nyx/persistent:/tmp/nyx-home" \
  --workdir /tmp /tmp/nyx/sandbox \
  --env TERM=$TERM "$@"

