# FOR LAMMPS (CPU), USE THE FOLLOWING MODULES
module purge
module use /mnt/software/modules/Core
module load gcc/13.3.0
module load openmpi/5.0.3
module load lammps/2Sep2026

which lmp
lmp -help

# FOR LAMMPS (GPU), USE THE FOLLOWING MODULES
module purge
module use /mnt/software/modules/Core

module load nvhpc/26.5
module load hpcx/2.50
module load lammps/2Sep2026

which lmp
lmp -help
