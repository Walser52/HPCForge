#!/usr/bin/env bash

set -euo pipefail

##############################################################################
# Configuration
##############################################################################

PROJECTS_ROOT="/mnt/data/projects"

##############################################################################
# Usage
##############################################################################

usage() {
    echo "Usage:"
    echo "    $0 <project-name> <template>"
    echo
    echo "Templates:"
    echo "    qe"
    echo "    orca"
    echo
    echo "Examples:"
    echo "    $0 CsPbBr3 qe"
    echo "    $0 TADF_Molecule orca"
    exit 1
}

##############################################################################
# Parse arguments
##############################################################################

if [[ $# -ne 2 ]]; then
    usage
fi

PROJECT_NAME="$1"
TEMPLATE="$2"
PROJECT_DIR="$PROJECTS_ROOT/$PROJECT_NAME"

##############################################################################
# Safety checks
##############################################################################

mkdir -p "$PROJECTS_ROOT"

if [[ -d "$PROJECT_DIR" ]]; then
    read -rp "Project '$PROJECT_NAME' already exists. Replace it? [y/N] " reply

    case "$reply" in
        y|Y|yes|YES)
            rm -rf "$PROJECT_DIR"
            ;;
        *)
            echo "Aborted."
            exit 0
            ;;
    esac
fi

##############################################################################
# Template definitions
##############################################################################

create_qe_project() {

    mkdir -p \
        "$PROJECT_DIR/calculations" \
        "$PROJECT_DIR/structures" \
        "$PROJECT_DIR/pseudopotentials" \
        "$PROJECT_DIR/workflows" \
        "$PROJECT_DIR/analysis" \
        "$PROJECT_DIR/figures" \
        "$PROJECT_DIR/docs" \
        "$PROJECT_DIR/scripts"

    cat > "$PROJECT_DIR/README.md" <<EOF
# $PROJECT_NAME

Quantum ESPRESSO project.

## Directory layout

- \`calculations/\` — Quantum ESPRESSO input/output files
- \`structures/\` — Structure files
- \`pseudopotentials/\` — Pseudopotential files
- \`workflows/\` — Workflow scripts and automation
- \`analysis/\` — Analysis scripts and results
- \`figures/\` — Generated figures
- \`docs/\` — Notes and documentation
- \`scripts/\` — Utility scripts

## Code

- Quantum ESPRESSO

## Project

Created: $(date +%Y-%m-%d)
Template: qe
EOF
}

create_orca_project() {

    mkdir -p \
        "$PROJECT_DIR/calculations" \
        "$PROJECT_DIR/structures" \
        "$PROJECT_DIR/workflows" \
        "$PROJECT_DIR/analysis" \
        "$PROJECT_DIR/figures" \
        "$PROJECT_DIR/docs" \
        "$PROJECT_DIR/scripts"

    cat > "$PROJECT_DIR/README.md" <<EOF
# $PROJECT_NAME

ORCA quantum-chemistry project.

## Directory layout

- \`calculations/\` — ORCA input/output files
- \`structures/\` — Molecular structures
- \`workflows/\` — Workflow scripts and automation
- \`analysis/\` — Analysis scripts and results
- \`figures/\` — Generated figures
- \`docs/\` — Notes and documentation
- \`scripts/\` — Utility scripts

## Code

- ORCA

## Project

Created: $(date +%Y-%m-%d)
Template: orca
EOF
}

##############################################################################
# Create project from template
##############################################################################

case "$TEMPLATE" in

    qe)
        create_qe_project
        ;;

    orca)
        create_orca_project
        ;;

    *)
        echo "Error: Unknown template '$TEMPLATE'."
        echo
        echo "Available templates:"
        echo "    qe"
        echo "    orca"
        exit 1
        ;;

esac

##############################################################################
# Done
##############################################################################

echo
echo "Created project:"
echo "    $PROJECT_DIR"
echo "Template:"
echo "    $TEMPLATE"
