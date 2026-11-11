#!/bin/bash
# ALICE3: runs every baseline in parallel, one P100 per job.  Usage, from the repository folder:
#   sbatch run_alice.sbatch                      # all jobs (first run also does the one-time setup)
#   sbatch --array=1 run_alice.sbatch            # only job 1 again (finished jobs are skipped, unfinished ones resume)
# When all jobs are done:  conda activate picst && python collect_results.py   -> send results.zip

#SBATCH --job-name=picst_sfda
#SBATCH --account=MY_HPC_PROJECT
#SBATCH --mail-user=MY_EMAIL@le.ac.uk
#SBATCH --mail-type=END,FAIL
#SBATCH --array=0-6
#SBATCH --gres=gpu:pascal:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=40G
#SBATCH --time=2-00:00:00
#SBATCH --output=%x-%A_%a.out
#SBATCH --error=%x-%A_%a.err
#SBATCH --export=None

# ---------- edit here ----------
# One job (method:setting) per array task; --array above must be 0..(number of jobs - 1).
JOB_LIST=(s3t_sfda:irrg stcgn:irrg snd:irrg dtst:rgb stable_st:rgb s3t_sfda:rgb stcgn:rgb)
HOURS=42           # each run pauses at its first evaluation after this many hours; keep it ~6 h below --time
TORCH_CUDA=cu126   # torch build for Pascal (P100) GPUs; also works on Ampere (A100)
# -------------------------------

cd "$SLURM_SUBMIT_DIR"

# One-time setup: task 0 installs (conda env "picst" + data), the other tasks wait for it.
# If it fails (e.g. no internet on GPU nodes), run on the login node:  TORCH_CUDA=cu126 bash setup.sh && touch .setup_done
if [[ $SLURM_ARRAY_TASK_ID == 0 && ! -f .setup_done ]]; then
    rm -f .setup_failed
    TORCH_CUDA=$TORCH_CUDA bash setup.sh && touch .setup_done || { touch .setup_failed; exit 1; }
fi
while [[ ! -f .setup_done ]]; do
    [[ -f .setup_failed ]] && { echo "setup failed in task 0" >&2; exit 1; }
    sleep 60
done

# This task's job. COLLECT=0: parallel tasks do not rewrite results/ at the same time.
JOBS=${JOB_LIST[$SLURM_ARRAY_TASK_ID]} HOURS=$HOURS COLLECT=0 bash run_all.sh
