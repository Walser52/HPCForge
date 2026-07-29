# HPC Build Framework

A lightweight build framework for installing scientific software from source into a clean, reproducible hierarchy.

The project was developed to build Quantum ESPRESSO and its dependencies, but it is designed to be easily extended to additional HPC packages such as Wannier90, Yambo, ELPA, PETSc, and others.

# Directory Layout

```
scripts/
│
├── config.sh
├── setup.sh
│
├── 00-system-deps.sh
├── 01-gcc.sh
├── 02-openmpi.sh
├── 03-openblas.sh
├── 04-scalapack.sh
├── 05-fftw.sh
├── 06-libxc.sh
├── 07-hdf5.sh
└── 08-qe.sh
│
├── downloads/
├── sources/
├── build/
└── logs/
```

Installed software is placed under

```
~/apps/

gcc/
└── 13.3.0/

    openmpi/
    └── 5.0.3/

    openblas/
    └── 0.3.30/

    scalapack/
    └── 2.2.0/

    fftw/
    └── 3.3.10/

    libxc/
    └── 7.0.0/

    hdf5/
    └── 1.14.6/

    qe/
    └── 7.4/
```

---

# Modules

Lmod module files are generated automatically.

Hierarchy:

    ```
    Core
    └── gcc

    Compiler
    └── openmpi

    MPI
    ├── openblas
    ├── scalapack
    ├── fftw
    ├── libxc
    ├── hdf5
    └── qe
    ```

Loading the compiler exposes compiler-dependent modules.

Loading MPI exposes MPI-dependent software.

# Workflow (For installation)

The recommended workflow is

    ```
    source setup.sh #

    ./01-gcc.sh

    module load gcc/13.3.0

    ./02-openmpi.sh

    module load openmpi/5.0.3

    ./03-openblas.sh
    ./04-scalapack.sh
    ./05-fftw.sh
    ./06-libxc.sh
    ./07-hdf5.sh

    ./08-qe.sh
    ```

# Workflow (After installation)



    ```
    module load qe/7.4

    pw.x
    ```

should be available.

# Configuration

All configuration is centralized in

    ```
    config.sh
    ```

This file defines

    - installation prefix
    - compiler
    - package versions
    - helper functions
    - module generation
    - installer defaults

    Individual installer scripts should **never** redefine these values.


# Checks 

    ```
    module use gcc/13.3.0
    which gcc

    module use openmpi/5.3.0
    which mpirun

    #openblas doesn't make executables but you can check the path variables.
    echo $LIBRARY_PATH
    echo $LD_LIBRARY_PATH
    echo $CPATH
    ```

# Quick Reference

    ```
    module show openblas/0.3.30
    ```

# Installer Interface

Every installer supports the same command-line interface.

    ```
    ./package.sh [OPTIONS]
    ```

## Common Options

    ```
    --force
    ```

Rebuild even if already installed.

    ```
    --module-only
    ```

Regenerate the module file without rebuilding.

    ```
    --jobs N
    ```

Build using N parallel jobs.

Example

    ```
    ./08-qe.sh --jobs 32
    ```

    ```
    --gpu
    ```

Enable GPU support (where supported).

Example

    ```
    ./08-qe.sh --gpu
    ```

    ```
    --help
    ```

Display usage information.


# Build Philosophy

The framework follows several design principles.

## Single source of configuration

All global configuration lives in `config.sh`.


## Out-of-source builds

Source directories are never polluted with build files.

Everything is built inside

    ```
    build/
    ```

## Versioned installations

Every package is installed into

    ```
    package/version
    ```

allowing multiple versions to coexist.


## Hierarchical modules

The module hierarchy prevents incompatible compiler and MPI combinations.



## Small installer scripts

Each installer should focus only on the package-specific build process.

Common functionality belongs in `config.sh`.


# Adding a New Package

A new installer typically requires

1. Define package name and version.
2. Download source.
3. Extract source.
4. Configure.
5. Build.
6. Install.
7. Verify installation.
8. Generate module.

Most installers are expected to be between 50 and 100 lines long.


# Current Packages

- GCC
- OpenMPI
- OpenBLAS
- ScaLAPACK
- FFTW
- LibXC
- HDF5
- Quantum ESPRESSO


# Future Packages

Possible additions include

- Wannier90
- Yambo
- ELPA
- PETSc
- SLEPc
- ELSI
- CP2K
- LAMMPS
- GROMACS


# License

This project is intended as a lightweight personal HPC build framework and may be freely adapted for other software stacks.