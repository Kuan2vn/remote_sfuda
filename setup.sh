#!/usr/bin/env bash
# One-time setup: conda env "picst" (Python 3.11) + requirements + data bundle.  Run: bash setup.sh
# The HF dataset is public; an optional HF_TOKEN=... in ./.env is picked up if present.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
env_name=${CONDA_ENV:-picst}
py_version=3.11    # new env; torch 2.8.0 has wheels only for Python <= 3.13 (an existing env with 3.10-3.13 is accepted)

if [[ -f "$root/.env" ]]; then set -a; . "$root/.env"; set +a; fi
if ! command -v conda >/dev/null 2>&1; then
    for hook in "$HOME/miniforge3/etc/profile.d/conda.sh" "$HOME/miniconda3/etc/profile.d/conda.sh" "$HOME/anaconda3/etc/profile.d/conda.sh" /opt/conda/etc/profile.d/conda.sh; do
        if [[ -f "$hook" ]]; then . "$hook"; break; fi
    done
fi
command -v conda >/dev/null 2>&1 || { echo 'conda not found (on HPC: module load the conda/anaconda module first)' >&2; exit 1; }
eval "$(conda shell.bash hook)"
if ! conda env list | awk '{print $1}' | grep -qx "$env_name"; then
    conda create -y -n "$env_name" -c conda-forge --override-channels "python=$py_version"
fi
set +u; conda activate "$env_name"; set -u    # some conda activate hooks read unset variables
python -c "import sys; sys.exit(not (3, 10) <= sys.version_info[:2] <= (3, 13))" || {
    echo "conda env '$env_name' has $(python -V); remove it (conda env remove -n $env_name) or set CONDA_ENV=other_name" >&2; exit 1; }

python -m pip install --upgrade pip
# torch 2.8.0 on PyPI (Linux) is the CUDA 12.8 build; PyPI also works behind TLS-inspecting firewalls.
# The CUDA 12.8 build does not support Pascal GPUs (e.g. P100). For them use the CUDA 12.6 build (also fine on newer GPUs):
#   TORCH_CUDA=cu126 bash setup.sh
# 2.8.0 is the version all reported results used; another version (untested): TORCH_PKGS="torch torchvision" bash setup.sh
if [[ -n "${TORCH_CUDA:-}" ]]; then
    python -m pip install "torch==2.8.0+$TORCH_CUDA" "torchvision==0.23.0+$TORCH_CUDA" --index-url "https://download.pytorch.org/whl/$TORCH_CUDA"
else
    python -m pip install ${TORCH_PKGS:-torch==2.8.0 torchvision==0.23.0}
fi
python -c 'import torch; torch.cuda.is_available() or print("Note: torch sees no GPU here (normal on a login node; run_all.sh must run on a GPU node)")'
python -c 'import torch; print("torch", torch.__version__, "CUDA", torch.version.cuda)'
python -m pip install -r "$root/requirements.txt"

cd "$root"
python download_data.py          # about 6.6 GB into ./data
for f in data/source_40000.pth data/gsd_sfuda_b2_irrg_v1 data/siamseg_sfuda_b2_v1 data/snd_warm; do
    [[ -e "$f" ]] || { echo "Missing after download: $f" >&2; exit 1; }
done
echo 'Setup complete. Next: bash run_all.sh'
