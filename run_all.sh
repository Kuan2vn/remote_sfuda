#!/usr/bin/env bash
# Run the pending baselines one after another (an interrupted run resumes; finished ones are skipped).
#   bash run_all.sh                               # default list below
#   JOBS="picst:irrg dtst:rgb" bash run_all.sh    # custom list (method:setting)
#   HOURS=10 bash run_all.sh                      # pause each run safely after ~10 h; re-run to resume
# HOURS limits the adaptation stage only (min 0.25); the St-CGN warm-up is not time-limited.
# Run it inside tmux on the GPU node. After every job it refreshes results/ and results.zip (send results.zip).
set -uo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
jobs=${JOBS:-"s3t_sfda:irrg stcgn:irrg snd:irrg dtst:rgb stable_st:rgb s3t_sfda:rgb stcgn:rgb"}
hours=${HOURS:-1000000}

env_name=${CONDA_ENV:-picst}
if ! command -v conda >/dev/null 2>&1; then
    for hook in "$HOME/miniconda3/etc/profile.d/conda.sh" "$HOME/anaconda3/etc/profile.d/conda.sh" /opt/conda/etc/profile.d/conda.sh; do
        if [[ -f "$hook" ]]; then . "$hook"; break; fi
    done
fi
command -v conda >/dev/null 2>&1 || { echo 'conda not found (load the conda module first)' >&2; exit 1; }
eval "$(conda shell.bash hook)"
set +u; conda activate "$env_name" || { echo "conda env '$env_name' not found; run bash setup.sh first" >&2; exit 1; }
cd "$root"

# experiment folder that run.py writes for a job (taken from METHODS in run.py)
exp_name() { python -c "import run; print(run.METHODS['$1'][1]['$2'])" 2>/dev/null; }

awk -v h="$hours" 'BEGIN { exit !(h >= 0.25) }' || { echo 'HOURS must be >= 0.25 (the runner refuses budgets under 15 min)' >&2; exit 2; }

for job in $jobs; do
    method=${job%%:*}
    setting=${job##*:}
    exp=$(exp_name "$method" "$setting") || true
    [[ -n "$exp" ]] || { echo "!! unknown job $job (method:setting, see METHODS in run.py)"; continue; }
    state="runs/$setting/$exp/seed1/RUN_STATE.json"
    if [[ -f "$state" ]] && grep -q '"status": "finished"' "$state"; then
        echo "== skip $job (finished)"
        continue
    fi
    echo "== $(date '+%F %T') start $job"
    python run.py --method "$method" --setting "$setting" --hours "$hours" || echo "!! $job failed (see $state)"
    python collect_results.py >/dev/null || true
done
python collect_results.py
