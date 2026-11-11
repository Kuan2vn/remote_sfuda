#!/usr/bin/env bash
# One-time setup: python venv ./.venv + requirements + data bundle.  Run: bash setup.sh
# The HF dataset is public; an optional HF_TOKEN=... in ./.env is picked up if present.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PYTHON=${PYTHON:-python3}    # needs Python >= 3.10; on HPC e.g. `module load python` first, or PYTHON=python3.11 bash setup.sh

if [[ -f "$root/.env" ]]; then set -a; . "$root/.env"; set +a; fi
"$PYTHON" -c 'import sys; sys.exit(sys.version_info < (3, 10))' || { echo "Need Python >= 3.10 (got $("$PYTHON" -V)); set PYTHON=python3.x" >&2; exit 1; }
[[ -d "$root/.venv" ]] || "$PYTHON" -m venv "$root/.venv"
. "$root/.venv/bin/activate"

python -m pip install --upgrade pip
# torch 2.8.0 on PyPI (Linux) is the CUDA 12.8 build, same as the cu128 index; PyPI also works behind TLS-inspecting firewalls.
# To use the PyTorch index instead: TORCH_INDEX=https://download.pytorch.org/whl/cu128 bash setup.sh
python -m pip install torch==2.8.0 torchvision==0.23.0 ${TORCH_INDEX:+--index-url "$TORCH_INDEX"}
python -c 'import torch; print("torch", torch.__version__, "CUDA", torch.version.cuda)'
python -m pip install -r "$root/requirements.txt"

cd "$root"
python download_data.py          # about 6.6 GB into ./data
for f in data/source_40000.pth data/gsd_sfuda_b2_irrg_v1 data/siamseg_sfuda_b2_v1 data/snd_warm; do
    [[ -e "$f" ]] || { echo "Missing after download: $f" >&2; exit 1; }
done
echo 'Setup complete. Next: bash run_all.sh'
