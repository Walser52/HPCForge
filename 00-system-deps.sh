#!/usr/bin/env bash

set -euo pipefail

sudo apt update

sudo apt install -y \
    build-essential \
    gfortran \
    cmake \
    git \
    wget \
    curl \
    pkg-config \
    lmod

