#!/bin/bash
# ALICE3 (University of Leicester) job array: one P100 per baseline job, all 7 jobs in parallel.
#
# Once, on the login node (internet needed). TORCH_CUDA=cu126 is required for Pascal (P100) GPUs:
#   TORCH_CUDA=cu126 bash setup.sh
# Edit --account and --mail-user below, then submit from the repository folder:
#   sbatch run_alice.sbatch
# A task that stops before finishing (time limit) resumes when resubmitted, e.g. task 1:  sbatch --array=1 run_alice.sbatch
# When all tasks are done:  conda activate picst && python collect_results.py   -> send results.zip
#
#SBATCH --job-name=picst_sfda
#SBATCH --account=MY_HPC_PROJECT
#SBATCH --array=0-6
#SBATCH --tasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=40G
#SBATCH --gres=gpu:pascal:1
#SBATCH --time=2-00:00:00
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=MY_EMAIL@le.ac.uk
#SBATCH --output=%x-%A_%a.out
#SBATCH --error=%x-%A_%a.err
#SBATCH --export=None

# No gcc/cuda/cudnn modules: the pip torch wheels bring their own CUDA and cuDNN (only the NVIDIA driver is used).
cd "$SLURM_SUBMIT_DIR"

# task index -> method:setting (same list as run_all.sh)
JOBS_LIST=(s3t_sfda:irrg stcgn:irrg snd:irrg dtst:rgb stable_st:rgb s3t_sfda:rgb stcgn:rgb)
job=${JOBS_LIST[$SLURM_ARRAY_TASK_ID]}
echo "task $SLURM_ARRAY_TASK_ID -> $job on $(hostname), $(date '+%F %T')"
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader

# HOURS=42: the run pauses safely at its first evaluation after 42 h, inside the 48 h limit
# (St-CGN's 2-3 h source warm-up is not counted). COLLECT=0: parallel tasks do not rewrite results/ at the same time.
JOBS="$job" HOURS=42 COLLECT=0 bash run_all.sh
