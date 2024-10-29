#!/bin/bash
#SBATCH --job-name=nyx
#SBATCH --mincpus 96
#SBATCH --exclusive
#SBATCH --mem 0
#SBATCH --partition fast
#SBATCH --nodes 1
#SBATCH --dependency=singleton
#SBATCH --time=12:00:00

# Errors in this script are critical
set -euo pipefail

# Sbatch only
if [ -z "${SLURM_JOB_ID:-}" ]; then
  echo 'TO RUN WITH SBATCH' >2
  exit 1
fi

echo "Welcome to $SLURM_JOB_ID at $(hostname)"

# Logs and tees to Pedro's Telegram
function log() {
  echo "$@"
  telegram-send --config ~/nyx/telegram.conf "$@"
  return $?
}

# Preprare container working directories
_S=/tmp/nyx/sandbox
mkdir -p /tmp/nyx/run $_S $HOME/nyx/{job,persistent}
export XDG_RUNTIME_DIR=/tmp/nyx/run

# Handle cleanup or re-usage of previous sandbox
if [[ "${2:-}" != "-e" ]]; then
  [ -e $_S ] && podman unshare rm -rf $_S
  singularity build --sandbox $_S $HOME/nyx/guest/latest
else
  mkdir -p $_S/{tmp/nyx-wd,var/tmp,proc,sys}
fi

# If not set, clone localtime from host
[ ! -e $_S/etc/localtime ] &&  podman unshare cp /etc/localtime $_S/etc/localtime

# Clone network stuff from host
cp /etc/{resolv.conf,hosts} $_S/etc/

# Prepare nyx-build working directory
_NYX_CURRENT="$HOME/nyx/job/$SLURM_JOB_ID"
mkdir "$_NYX_CURRENT"

# Handles building any branch
_NYX_BRANCH=${1:-/bump/$(date +%Y%m%d)-1}
if [[ ${_NYX_BRANCH:0:1} != "/" ]] ; then
  log "Invalid Nyx branch $_NYX_BRANCH"
  exit 1
fi
_NYX_TARGET_FLAKE="github:chaotic-cx/nyx$_NYX_BRANCH?dir=maintenance"

# Default headless behavior
_S_CMD=exec
_S_TARGET=chaotic-nyx-build

# Allow interactive terminals with "srun"
if [[ ${TERM:-dummy} != dummy ]]; then
  _S_CMD=shell
  _S_TARGET=bash
fi

# Starts the container and run nyx-build
log "Building '$_NYX_TARGET_FLAKE' job $SLURM_JOB_ID at $(hostname)"
if singularity $_S_CMD --writable --fakeroot --no-home --containall \
  -B '/dev/full:/dev/full' \
  -B "$_NYX_CURRENT:/tmp/nyx-wd" \
  -B "$HOME/nyx/persistent:/tmp/nyx-home" \
  --workdir /tmp $_S \
  nix develop --no-write-lock-file "$_NYX_TARGET_FLAKE" --refresh -c env \
  NYX_WD="/tmp/nyx-wd" NYX_HOME="/tmp/nyx-home" NYX_PUSH_ALL=1 \
  CACHIX_AUTH_TOKEN="$(cat $HOME/nyx/cachix.secret)" \
  $_S_TARGET; then
  log "Finished building '$_NYX_TARGET_FLAKE' job $SLURM_JOB_ID at $(hostname) with $?"
else
  _ERROR=$?
  log "Failure building '$_NYX_TARGET_FLAKE' job $SLURM_JOB_ID at $(hostname) with $_ERROR"
fi

# Submits the failures to Pedro's Telegram
[ -e "$_NYX_CURRENT/failures.txt" ] && log -f "$_NYX_CURRENT/failures.txt"

# The end.
echo "Finished."
exit 0

