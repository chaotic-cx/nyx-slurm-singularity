#!/bin/bash
#SBATCH --job-name=nyx
#SBATCH --mincpus 128
#SBATCH --exclusive
#SBATCH --mem 0
#SBATCH --partition fast
#SBATCH --nodes 1
#SBATCH --dependency=singleton
#SBATCH --time=04:00:00

set -euo pipefail

mkdir -p /tmp/nyx/{run,sandbox} $HOME/nyx/{job,persistent}
export XDG_RUNTIME_DIR=/tmp/nyx/run

if [[ "${2:-}" != "-e" ]]; then
  [[ -e /tmp/nyx/sandbox ]] && podman unshare rm -rf /tmp/nyx/sandbox
  singularity build --sandbox /tmp/nyx/sandbox $HOME/nyx/guest/latest
else
  mkdir -p /tmp/nyx/sandbox/{tmp/nyx-wd,var/tmp,proc,sys}
  [ ! -e /tmp/nyx/sandbox/etc/localtime ] && cp --preserve=links /etc/localtime 7
fi

_NYX_CURRENT="$HOME/nyx/job/$SLURM_JOB_ID"
mkdir "$_NYX_CURRENT"

_NYX_TARGET_FLAKE="github:chaotic-cx/nyx${1:-/bump/$(date +%Y%m%d)-1}"

echo "Building '$_NYX_TARGET_FLAKE' job $SLURM_JOB_ID at $(hostname)"

exec singularity exec --writable --fakeroot --no-home --containall \
  -B '/dev/full:/dev/full' \
  -B "$_NYX_CURRENT:/tmp/nyx-wd" \
  -B "$HOME/nyx/persistent:/var/nyx" \
  --workdir /tmp /tmp/nyx/sandbox \
  nix develop "$_NYX_TARGET_FLAKE" -c env \
  NYX_WD="/tmp/nyx-wd" NYX_HOME="/var/nyx" \
  CACHIX_AUTH_TOKEN="$(cat $HOME/nyx/cachix.secret)" \
  chaotic-nyx-build

