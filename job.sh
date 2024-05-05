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

# Logs and tees to Pedro's Telegram
function log() {
  echo "$@"
  telegram-send --config ~/nyx/telegram.conf "$@"
  return $?
}

# Preprare container working directories
mkdir -p /tmp/nyx/{run,sandbox} $HOME/nyx/{job,persistent}
export XDG_RUNTIME_DIR=/tmp/nyx/run

# Handle cleanup or re-usage of previous sandbox
if [[ "${2:-}" != "-e" ]]; then
  [[ -e /tmp/nyx/sandbox ]] && podman unshare rm -rf /tmp/nyx/sandbox
  singularity build --sandbox /tmp/nyx/sandbox $HOME/nyx/guest/latest
else
  mkdir -p /tmp/nyx/sandbox/{tmp/nyx-wd,var/tmp,proc,sys}
  [ ! -e /tmp/nyx/sandbox/etc/localtime ] && cp --preserve=links /etc/localtime 7
fi

# Prepare nyx-build working directory
_NYX_CURRENT="$HOME/nyx/job/$SLURM_JOB_ID"
mkdir "$_NYX_CURRENT"

# Handles building any branch
_NYX_BRANCH=${1:-/bump/$(date +%Y%m%d)-1}
if [[ ${_NYX_BRANCH:0:1} != "/" ]] ; then
  log "Invalid Nyx branch $_NYX_BRANCH"
  exit 1
fi
_NYX_TARGET_FLAKE="github:chaotic-cx/nyx$_NYX_BRANCH"

# Starts the container and run nyx-build
log "Building '$_NYX_TARGET_FLAKE' job $SLURM_JOB_ID at $(hostname)"
if singularity exec --writable --fakeroot --no-home --containall \
  -B '/dev/full:/dev/full' \
  -B "$_NYX_CURRENT:/tmp/nyx-wd" \
  -B "$HOME/nyx/persistent:/tmp/nyx-home" \
  --workdir /tmp /tmp/nyx/sandbox \
  nix develop "$_NYX_TARGET_FLAKE" -c env \
  NYX_WD="/tmp/nyx-wd" NYX_HOME="/tmp/nyx-home" \
  CACHIX_AUTH_TOKEN="$(cat $HOME/nyx/cachix.secret)" \
  chaotic-nyx-build; then
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

