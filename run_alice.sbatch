#!/bin/bash
# ALICE3 (University of Leicester): everything in one submission.
#   1. Edit --account and --mail-user below.
#   2. From the repository folder:  sbatch run_alice.sbatch
# It is a job array: one P100 per baseline job, all 7 jobs in parallel. Task 0 first runs the one-time setup
# (conda env "picst" with the Pascal-compatible torch build, ~6.6 GB data); the other tasks wait for it.
# If the GPU nodes have no internet, setup fails and every task stops with a message: then run once on the login node
#   TORCH_CUDA=cu126 bash setup.sh && touch .setup_done
# and submit again. Finished jobs are skipped and unfinished ones resume, so resubmitting is always safe
# (one task only, e.g. task 1:  sbatch --array=1 run_alice.sbatch).
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
task=${SLURM_ARRAY_TASK_ID:-0}

# --- one-time setup (task 0 only; the marker files live in the repository folder) ---
if [[ ! -f .setup_done ]]; then
    if [[ "$task" == 0 ]]; then
        rm -f .setup_failed
        echo "$(date '+%F %T') running setup.sh"
        if TORCH_CUDA=cu126 bash setup.sh; then touch .setup_done; else touch .setup_failed; echo 'setup.sh failed (see above)' >&2; exit 1; fi
    else
        echo "$(date '+%F %T') waiting for task 0 to finish setup"
        for _ in $(seq 1 240); do                      # up to 4 h
            [[ -f .setup_done ]] && break
            [[ -f .setup_failed ]] && { echo 'setup failed in task 0; see its .err file' >&2; exit 1; }
            sleep 60
        done
        [[ -f .setup_done ]] || { echo 'setup did not finish within 4 h' >&2; exit 1; }
    fi
fi

# --- this task's job (same list and order as run_all.sh) ---
JOBS_LIST=(s3t_sfda:irrg stcgn:irrg snd:irrg dtst:rgb stable_st:rgb s3t_sfda:rgb stcgn:rgb)
job=${JOBS_LIST[$task]}
echo "task $task -> $job on $(hostname), $(date '+%F %T')"
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader

# HOURS=42: the run pauses safely at its first evaluation after 42 h, inside the 48 h limit
# (St-CGN's 2-3 h source warm-up is not counted). COLLECT=0: parallel tasks do not rewrite results/ at the same time.
JOBS="$job" HOURS=42 COLLECT=0 bash run_all.sh
