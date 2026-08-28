# HPCForge

**HPCForge** is a reproducible software deployment framework for scientific and high-performance computing environments.

It provides a structured collection of Bash installers for compilers, MPI implementations, numerical libraries, scientific applications, and post-processing tools. Software is installed into a predictable directory hierarchy and exposed through **Lmod environment modules**.

The guiding principle is:

> **The installer is the source of truth; the module is the interface.**

The goal is that a user should be able to install or regenerate a software stack without manually constructing module files or modifying individual applications' environment settings.

---

# 1. Repository Structure

The repository is organized approximately as follows:

```text
HPCForge/
│
├── config.sh
│
├── installers/
│   ├── 00-system-deps.sh
│   ├── 01-gcc.sh
│   ├── 02-openmpi.sh
│   ├── ...
│   ├── 08-qe.sh
│   ├── 08a-unfold-x.sh
│   ├── ...
│   └── orca installer
│
├── docs/
│   └── ...
│
└── README.md
```

The installed software tree is separate from the source repository:

```text
/mnt/software/
│
├── apps/
│   ├── gcc/
│   │   └── 13.3.0/
│   │       ├── openmpi/
│   │       ├── openblas/
│   │       ├── scalapack/
│   │       ├── fftw/
│   │       ├── libxc/
│   │       ├── hdf5/
│   │       └── qe/
│   │
│   ├── nvhpc/
│   └── ...
│
├── downloads/
│
├── sources/
│
├── build/
│
└── modules/
    ├── Core/
    ├── Compiler/
    └── MPI/
```

The exact hierarchy may evolve, but the separation between **source**, **build**, **installation**, and **module files** should be preserved.

---

# 2. The Four Important Directories

## 2.1 `apps/`

Contains the actual installed software.

For example:

```text
/mnt/software/apps/gcc/13.3.0/
```

may contain:

```text
openmpi/5.0.3/
openblas/0.3.30/
scalapack/2.2.0/
fftw/3.3.10/
libxc/7.0.0/
hdf5/1.14.6/
qe/7.4/
```

Software should normally **not** be installed manually into this tree.

Use the appropriate installer.

---

## 2.2 `downloads/`

Contains downloaded source archives and installers.

For example:

```text
/mnt/software/downloads/
```

The installer framework is designed to avoid downloading a file again when the required archive is already present.

---

## 2.3 `sources/`

Contains extracted source trees used during compilation.

The extraction helper removes the previous source directory before extracting a new copy. Consequently, this directory should be regarded as a **working area**, not as permanent source storage.

---

## 2.4 `build/`

Contains temporary or intermediate build directories.

Build directories can generally be removed after a successful installation unless they are being retained for debugging or reproducibility purposes.

---

# 3. `config.sh`

`config.sh` is the central configuration file for HPCForge.

Installer scripts should source it rather than independently defining installation paths, package versions, or common helper functions.

The configuration currently defines:

* installation paths;
* compiler versions;
* MPI versions;
* numerical library versions;
* Quantum ESPRESSO version;
* CUDA configuration;
* NVIDIA HPC SDK configuration;
* common installer options;
* compiler/toolchain detection;
* helper functions;
* module-generation functions;
* common command-line argument handling.

The current configuration follows the principle:

```text
config.sh
     │
     ├── paths
     ├── versions
     ├── toolchain selection
     ├── helper functions
     └── module generation
             │
             ▼
       installer scripts
```

The current configuration uses:

```bash
SOFTWARE_ROOT="/mnt/software"

PREFIX="$SOFTWARE_ROOT/apps"
DOWNLOAD="$SOFTWARE_ROOT/downloads"
BUILD="$SOFTWARE_ROOT/build"
MODULES="$SOFTWARE_ROOT/modules"
SRC="$SOFTWARE_ROOT/sources"
```

These locations should be changed if HPCForge is deployed on another machine with a different software filesystem.

---

# 4. What Users Should Change

The beginning of `config.sh` should be treated as the **user configuration section**.

The most important settings are:

```bash
SOFTWARE_ROOT="/mnt/software"
```

and the software versions, for example:

```bash
GCC_VERSION="13.3.0"

MPI_VERSION="5.0.3"

OPENBLAS_VERSION="0.3.30"
SCALAPACK_VERSION="2.2.0"
FFTW_VERSION="3.3.10"
LIBXC_VERSION="7.0.0"
HDF5_VERSION="1.14.6"

QE_VERSION="7.4"
```

GPU installations additionally depend on:

```bash
CUDA_VERSION="12.9"
CUDA_PATCH="12.9.0"
CUDA_ARCHITECTURES="70"

NVHPC_VERSION="26.5"
HPCX_VERSION="2.50"
```

## Settings normally changed by the administrator

| Setting              | Purpose                                    |
| -------------------- | ------------------------------------------ |
| `SOFTWARE_ROOT`      | Root of the HPCForge software installation |
| `GCC_VERSION`        | GCC version                                |
| `MPI_VERSION`        | Default GCC/OpenMPI version                |
| `OPENBLAS_VERSION`   | OpenBLAS version                           |
| `SCALAPACK_VERSION`  | ScaLAPACK version                          |
| `FFTW_VERSION`       | FFTW version                               |
| `LIBXC_VERSION`      | LibXC version                              |
| `HDF5_VERSION`       | HDF5 version                               |
| `QE_VERSION`         | Quantum ESPRESSO version                   |
| `CUDA_VERSION`       | CUDA toolkit version                       |
| `CUDA_ARCHITECTURES` | GPU compute capability                     |
| `NVHPC_VERSION`      | NVIDIA HPC SDK version                     |
| `HPCX_VERSION`       | HPC-X version                              |

For a new machine, these are the first settings that should be reviewed.

---

# 5. Settings Users Normally Should Not Change

The following should generally be left alone unless the installer framework itself is being modified:

```bash
MPI_ROOT
OPENBLAS_ROOT
SCALAPACK_ROOT
FFTW_ROOT
LIBXC_ROOT
HDF5_ROOT
QE_ROOT
```

These are derived from the selected toolchain.

Similarly, installer helper functions such as:

```bash
load_toolchain()
load_dependencies()
write_module()
download()
extract()
installed()
already_installed()
```

should not be independently reimplemented in application installers.

This keeps the installers consistent.

---

# 6. Toolchains

HPCForge supports more than one compiler/toolchain.

The two important toolchains currently are:

```text
GCC
 │
 └── OpenMPI
      └── CPU applications
```

and:

```text
NVIDIA HPC SDK
 │
 └── HPC-X
      └── CUDA/GPU applications
```

The GCC toolchain currently uses:

```text
GCC 13.3.0
OpenMPI 5.0.3
```

The NVIDIA toolchain currently uses:

```text
NVHPC 26.5
HPC-X 2.50
CUDA
```

The toolchain-selection logic in `config.sh` establishes the compiler, MPI implementation, compiler wrappers, and installation roots.

---

# 7. CPU and GPU Builds

Applications which support both CPU and GPU builds should make the distinction explicit.

For example, Quantum ESPRESSO is installed as:

```text
qe/7.4-cpu
qe/7.4-cuda
```

rather than relying on a generic:

```text
qe/7.4
```

This makes the execution environment unambiguous.

The intended relationship is:

```text
CPU
    gcc
     │
     └── OpenMPI
          │
          └── QE 7.4 CPU


GPU
    NVHPC
     │
     └── HPC-X
          │
          └── QE 7.4 CUDA
```

The module name therefore communicates which executable/toolchain is being loaded.

---

# 8. Installer Conventions

Installers should follow a common structure.

A typical installer should:

1. source `config.sh`;
2. parse common options;
3. select the appropriate toolchain;
4. establish package-specific paths;
5. download the source/archive;
6. extract or unpack it;
7. build/install the software;
8. verify the installation;
9. generate the corresponding Lmod module.

The common command-line conventions are:

```text
--module-only
--force
--cpu
--gpu
--debug
--release
--jobs N
--prefix DIR
--version VERSION
```

Not every installer necessarily needs every option, but installers should follow the framework conventions where applicable.

---

# 9. Installer Reference

The master documentation should maintain a table for every installer.

| Script              | Software            | Toolchain     | CPU/GPU | Notes                        |
| ------------------- | ------------------- | ------------- | ------- | ---------------------------- |
| `00-system-deps.sh` | System dependencies | System        | —       | Initial system preparation   |
| `01-gcc.sh`         | GCC                 | GCC           | CPU     | Compiler                     |
| `02-openmpi.sh`     | OpenMPI             | GCC           | CPU     | MPI implementation           |
| `...`               | ...                 | ...           | ...     | ...                          |
| `08-qe.sh`          | Quantum ESPRESSO    | GCC/NVHPC     | CPU/GPU | Main DFT package             |
| `08a-unfold-x.sh`   | `unfold.x`          | GCC/QE CPU    | CPU     | QE post-processor            |
| ORCA installer      | ORCA                | ORCA-specific | CPU     | Official binary distribution |

Each script should eventually have a short entry containing:

```text
Purpose
Dependencies
Toolchain
Installation location
Module name
Command-line options
User-configurable settings
Important caveats
Verification command
```

---

# 10. Quantum ESPRESSO — `08-qe.sh`

`08-qe.sh` installs Quantum ESPRESSO and supports separate CPU and GPU builds.

The current QE version is:

```text
7.4
```

The intended module naming convention is:

```text
qe/7.4-cpu
qe/7.4-cuda
```

rather than:

```text
qe/7.4
```

This distinction is important because the two installations are built with different compiler/MPI toolchains.

## CPU build

The CPU build uses the GCC toolchain.

Conceptually:

```text
GCC
 └── OpenMPI
      ├── FFTW
      ├── OpenBLAS
      ├── ScaLAPACK
      ├── LibXC
      ├── HDF5
      └── QE
```

The build is invoked with:

```bash
./installers/08-qe.sh --version 7.4 --cpu
```

The resulting module is:

```text
qe/7.4-cpu
```

Load it with:

```bash
module purge
module use /mnt/software/modules/Core
module load qe/7.4-cpu
```

Verification:

```bash
which pw.x
pw.x --help
```

---

## GPU build

The GPU build uses the NVIDIA HPC SDK toolchain and CUDA-enabled dependencies.

The relevant configuration currently includes:

```text
NVHPC 26.5
HPC-X 2.50
CUDA 12.9
CUDA architecture 70
```

The GPU build is invoked with:

```bash
./installers/08-qe.sh --version 7.4 --gpu
```

The resulting module is:

```text
qe/7.4-cuda
```

The CUDA architecture must correspond to the GPUs on the target system.

For example:

```text
V100 → 70
A100 → 80
H100 → 90
```

Therefore, **`CUDA_ARCHITECTURES` is a machine-specific setting** and should be reviewed when HPCForge is moved to another GPU system.

---

# 11. QE Dependencies

The QE build currently relies on several numerical and scientific libraries.

The relevant versions are maintained centrally in `config.sh`:

```text
OpenBLAS   0.3.30
ScaLAPACK  2.2.0
FFTW       3.3.10
LibXC      7.0.0
HDF5       1.14.6
```

These should not be hard-coded independently into `08-qe.sh`.

Instead, `08-qe.sh` should obtain the versions and installation paths from `config.sh`.

This ensures that changing a dependency version requires changing it in one place.

---

# 12. QE Post-Processors

Post-processing programs which depend on Quantum ESPRESSO should explicitly document **which QE build they were compiled against**.

For example:

```text
unfold.x
   │
   └── qe/7.4-cpu
```

The CPU post-processor should not accidentally be compiled against the CUDA QE toolchain merely because the CUDA version happens to be loaded in the user's shell.

This is why post-processors should explicitly load their intended toolchain during compilation.

The module dependency should make the relationship visible to the user.

---

# 13. ORCA

ORCA is treated differently from software such as Quantum ESPRESSO because the official distribution is provided as a precompiled binary package rather than being compiled from source as part of the HPCForge numerical-library stack.

The ORCA installer therefore follows a different model:

```text
official ORCA distribution
          │
          ▼
      installation
          │
          ▼
       ORCA module
```

The installer is responsible for:

* obtaining the official ORCA binary distribution;
* installing it into the HPCForge software hierarchy;
* configuring the required runtime environment;
* generating an Lmod module;
* supporting `--force`;
* supporting `--module-only`;
* accepting `--jobs N` for framework consistency where applicable.

The ORCA installation uses the **AVX2 build** and its required MPI environment.

A particularly important distinction is that ORCA's MPI requirement is not necessarily the same as the MPI used by the main GCC scientific stack.

The main GCC stack currently uses:

```text
OpenMPI 5.0.3
```

whereas the ORCA installation is intended to use:

```text
OpenMPI 4.1.8
```

These should therefore **not be silently conflated**.

The documentation should explicitly record the MPI environment expected by ORCA.

---

# 14. Why ORCA Has a Separate MPI

The existence of multiple MPI versions is intentional.

HPCForge should not assume:

```text
one MPI version = every application
```

Instead:

```text
Application
    │
    └── required toolchain
            │
            └── required MPI
```

For example:

```text
Quantum ESPRESSO CPU
    └── GCC 13.3.0
          └── OpenMPI 5.0.3


ORCA
    └── ORCA-supported runtime
          └── OpenMPI 4.1.8
```

The correct module hierarchy should prevent users from accidentally mixing incompatible MPI environments.

---

# 15. Module Files

Module files are generated by the installer framework.

Users should normally **not manually edit generated module files**.

The intended workflow is:

```text
installer
    │
    ├── installation
    │
    └── module generation
             │
             ▼
        Lmod module
```

If a module file needs to change because the installation has changed, regenerate it using the installer:

```bash
./installer.sh --module-only
```

This preserves the installer as the source of truth.

---

# 16. Typical User Workflow

After HPCForge has been installed, users should generally interact with the software through modules.

For example:

```bash
module purge
module use /mnt/software/modules/Core
module load qe/7.4-cpu
```

or:

```bash
module purge
module use /mnt/software/modules/Core
module load qe/7.4-cuda
```

Then:

```bash
which pw.x
```

should identify the executable provided by the selected module.

Users should avoid manually modifying:

```text
PATH
LD_LIBRARY_PATH
LIBRARY_PATH
CPATH
```

unless there is a specific reason to do so.

The module system should establish the required environment.

---

# 17. Changing Software Versions

To upgrade a package, change its version in `config.sh` where appropriate.

For example:

```bash
QE_VERSION="7.4"
```

could eventually become:

```bash
QE_VERSION="7.x"
```

The installer should then be run with the new version.

For applications supporting version overrides, the version can also be supplied directly:

```bash
./installers/08-qe.sh --version 7.4
```

The exact behavior of each installer should be documented in its individual section.

---

# 18. Reinstallation

The framework supports:

```bash
--force
```

for installers where rebuilding an existing installation is appropriate.

For example:

```bash
./installers/08-qe.sh --force --cpu
```

`--force` should be used deliberately.

It should not be necessary merely to regenerate a module. For that purpose use:

```bash
--module-only
```

---

# 19. Verification

Every installer should ideally provide a simple verification procedure.

At minimum:

```bash
module load <module>
which <executable>
<executable> --version
```

For MPI applications, also verify:

```bash
which mpirun
mpirun --version
```

and, where appropriate:

```bash
mpirun -np 2 <executable>
```

Verification should be performed immediately after installation rather than assuming that a successful compilation implies a correct runtime environment.

---

# 20. Important Design Rules

HPCForge follows several rules that should be preserved as the project grows.

### Rule 1 — `config.sh` is the central configuration source

Do not duplicate package versions or installation roots across installers.

### Rule 2 — Installers are the source of truth

Do not manually maintain module files.

### Rule 3 — Toolchains must be explicit

CPU and GPU builds should clearly identify the compiler/MPI environment used to build them.

### Rule 4 — Dependencies should be explicit

An application should document the libraries against which it was compiled.

### Rule 5 — Do not mix MPI environments casually

Different applications may require different MPI versions.

### Rule 6 — Machine-specific settings belong in configuration

Examples include:

```text
software root
CUDA version
GPU architecture
compiler version
MPI version
```

### Rule 7 — Application-specific logic belongs in the installer

The common framework should provide paths, toolchains, dependency loading, argument parsing, and module generation. The individual installer should contain the actual application build/install procedure.

---

# 21. Installer Documentation Template

Every installer entry in this document should eventually use the following structure:

```markdown
## NN — Application Name

### Purpose

What the installer installs and why it exists.

### Version

Current version.

### Toolchain

Compiler, MPI, CUDA/NVHPC, etc.

### Dependencies

Required libraries and their versions.

### Installation

Installation directory.

### Module

Module name and hierarchy.

### Usage

Example installer commands.

### User-configurable settings

Settings in `config.sh` that may need to be changed.

### Important caveats

Compatibility issues, special requirements, or reasons
why this installer differs from the others.

### Verification

Commands used to verify the installation.
```

This keeps the master document useful as the number of HPCForge installers grows.

---

# 22. Current Software Stack

The current configuration includes, among others:

| Component        | Version |
| ---------------- | ------: |
| GCC              |  13.3.0 |
| OpenMPI          |   5.0.3 |
| OpenBLAS         |  0.3.30 |
| ScaLAPACK        |   2.2.0 |
| FFTW             |  3.3.10 |
| LibXC            |   7.0.0 |
| HDF5             |  1.14.6 |
| Quantum ESPRESSO |     7.4 |
| NVHPC            |    26.5 |
| HPC-X            |    2.50 |
| CUDA             |    12.9 |

The ORCA environment is maintained separately where its compatibility requirements differ from the main HPCForge toolchain.

---

# 23. Philosophy

HPCForge is intended to make a scientific HPC environment **reproducible, inspectable, and maintainable**.

A user should be able to answer:

```text
Where is this software installed?
Which compiler built it?
Which MPI does it use?
Which libraries does it depend on?
Which module loads it?
Which script installed it?
Which configuration produced it?
```

without having to reconstruct the history of the machine manually.

The desired dependency chain is therefore:

```text
                    config.sh
                        │
             ┌──────────┴──────────┐
             │                     │
        Toolchains            Versions
             │                     │
             └──────────┬──────────┘
                        │
                   Installer
                        │
              ┌─────────┴─────────┐
              │                   │
          Application          Module
              │                   │
              └─────────┬─────────┘
                        │
                       User
```

The system should remain understandable even after dozens of applications have been added.

---
