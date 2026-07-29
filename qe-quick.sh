#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: qe-quick <version> <cpu|gpu>"
    exit 1
}

[[ $# -eq 2 ]] || usage

VERSION="$1"
TARGET="${2,,}"

module purge
module use /mnt/software/modules/Core

case "$TARGET" in
    gpu)
        module load nvhpc/26.5
        module load fftw/3.3.10
        module load hpcx/2.50
        module load libxc/7.0.0
        module load openblas/0.3.30
        module load hdf5/1.14.6
        module load scalapack/2.2.0
        module load qe/${VERSION}
        ;;

    cpu)
        module load gcc/13.3.0
        module load fftw/3.3.10
        module load openmpi/5.0.3
        module load libxc/7.0.0
        module load openblas/0.3.30
        module load hdf5/1.14.6
        module load scalapack/2.2.0
        module load qe/${VERSION}
        ;;

    *)
        echo "Target must be 'cpu' or 'gpu'."
        exit 1
        ;;
esac