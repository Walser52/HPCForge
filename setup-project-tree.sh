#!/usr/bin/env bash

set -euo pipefail

##############################################################################
# Configuration
##############################################################################

PROJECTS_ROOT="/mnt/data/projects"

##############################################################################
# Parse arguments
##############################################################################

if [[ $# -ne 1 ]]; then
    echo "Usage:"
    echo "    $0 <project-name>"
    exit 1
fi

PROJECT_NAME="$1"
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
# Directory structure
##############################################################################

mkdir -p \
    "$PROJECT_DIR/calculations" \
    "$PROJECT_DIR/structures" \
    "$PROJECT_DIR/pseudopotentials" \
    "$PROJECT_DIR/workflows" \
    "$PROJECT_DIR/analysis" \
    "$PROJECT_DIR/figures" \
    "$PROJECT_DIR/docs" \
    "$PROJECT_DIR/scripts"

##############################################################################
# README
##############################################################################

cat > "$PROJECT_DIR/README.md" <<'EOF'
# Project

## Directory layout
...
EOF