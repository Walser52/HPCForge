#!/usr/bin/env bash
#
# setup-data-tree.sh
#
# Creates a standard directory layout for computational research.
#
# Usage:
#     ./setup-data-tree.sh
#     ./setup-data-tree.sh /mnt/data
#

set -euo pipefail

ROOT="${1:-/mnt/data}"

echo "Creating data tree under:"
echo "    $ROOT"
echo

##############################################################################
# Top-level directories
##############################################################################

mkdir -p \
    "$ROOT/archive" \
    "$ROOT/databases" \
    "$ROOT/projects" \
    "$ROOT/pseudopotentials" \
    "$ROOT/scratch" \
    "$ROOT/shared" \
    "$ROOT/templates" \
    "$ROOT/workflows"

##############################################################################
# Databases
##############################################################################

mkdir -p \
    "$ROOT/databases/materials-project" \
    "$ROOT/databases/qmof" \
    "$ROOT/databases/cod" \
    "$ROOT/databases/cif"

##############################################################################
# Pseudopotentials
##############################################################################

mkdir -p \
    "$ROOT/pseudopotentials/sssp" \
    "$ROOT/pseudopotentials/pslibrary" \
    "$ROOT/pseudopotentials/oncv" \
    "$ROOT/pseudopotentials/custom"

##############################################################################
# Shared resources
##############################################################################

mkdir -p \
    "$ROOT/shared/scripts" \
    "$ROOT/shared/notebooks" \
    "$ROOT/shared/structures" \
    "$ROOT/shared/utilities"

##############################################################################
# Templates
##############################################################################

mkdir -p \
    "$ROOT/templates/qe" \
    "$ROOT/templates/lammps" \
    "$ROOT/templates/wannier90" \
    "$ROOT/templates/perturbo"

##############################################################################
# Workflows
##############################################################################

mkdir -p \
    "$ROOT/workflows/aiida" \
    "$ROOT/workflows/python" \
    "$ROOT/workflows/bash"

##############################################################################
# Scratch
##############################################################################

mkdir -p \
    "$ROOT/scratch/qe" \
    "$ROOT/scratch/lammps" \
    "$ROOT/scratch/aiida"

##############################################################################
# README files
##############################################################################

cat > "$ROOT/README.md" <<EOF
# Computational Research Data

This directory contains all scientific data.

## Layout

archive/              Completed or frozen projects

databases/            Downloaded databases

projects/             Active research projects

pseudopotentials/     Pseudopotential libraries

scratch/              Temporary runtime files

shared/               Shared scripts and utilities

templates/            Input templates

workflows/            Automation and workflow scripts
EOF

cat > "$ROOT/projects/README.md" <<EOF
# Projects

Each project should follow a layout similar to:

project-name/
├── calculations/
├── data/
├── figures/
├── manuscript/
├── notes/
├── results/
└── scripts/
EOF

##############################################################################
# Done
##############################################################################

echo "============================================================"
echo " Data directory initialized"
echo "============================================================"
echo
echo "Root:"
echo "    $ROOT"
echo
echo "Projects:"
echo "    $ROOT/projects"
echo
echo "Scratch:"
echo "    $ROOT/scratch"
echo
echo "Templates:"
echo "    $ROOT/templates"
echo
echo "Done."