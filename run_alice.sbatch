#!/bin/bash
# ALICE3: runs the baselines one after another on one P100.  Usage, from the repository folder:
#   sbatch run_alice.sbatch
# The first run also does the one-time setup. Resubmitting is safe: finished jobs are skipped, an unfinished one resumes.
# results.zip is refreshed after every job: send it.

#SBATCH --job-name=picst_sfda
#SBATCH --account=MY_HPC_PROJECT
#SBATCH --mail-user=MY_EMAIL@le.ac.uk
#SBATCH --mail-type=END,FAIL
#SBATCH --gres=gpu:pascal:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=40G
#SBATCH --time=7-00:00:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
#SBATCH --export=None

# ---------- edit here ----------
JOBS="s3t_sfda:irrg stcgn:irrg snd:irrg dtst:rgb stable_st:rgb s3t_sfda:rgb stcgn:rgb"   # method:setting, run in this order
TORCH_CUDA=cu126   # torch build for Pascal (P100) GPUs; also works on Ampere (A100)
# -------------------------------

cd "$SLURM_SUBMIT_DIR"

# One-time setup (conda env "picst" + data). If it fails (e.g. no internet on GPU nodes),
# run on the login node:  TORCH_CUDA=cu126 bash setup.sh && touch .setup_done   and submit again.
if [[ ! -f .setup_done ]]; then
    TORCH_CUDA=$TORCH_CUDA bash setup.sh && touch .setup_done || exit 1
fi

JOBS=$JOBS bash run_all.sh
