# PIC-ST and SFDA baselines (VH → PD)

Internal copy for the authors. Source-free domain adaptation from ISPRS Vaihingen (IRRG) to Potsdam, SegFormer-B2.
Method details: [docs/METHODS.md](docs/METHODS.md). Results: [docs/RESULTS.md](docs/RESULTS.md).
Needs Linux with one NVIDIA GPU and conda (Miniforge, Miniconda or Anaconda in the home folder, or a loaded conda module).

## 1. Setup (once)

Downloads the Hugging Face dataset `kuan2/picst-rs-sfda-data`. No token is needed while it is public; otherwise put a read token (ask the owner) in `.env`: `echo 'HF_TOKEN=hf_xxx' > .env`.

```bash
bash setup.sh        # conda env "picst" (Python 3.11), requirements, ~6.6 GB data into ./data
```

On Pascal GPUs (e.g. P100) use `TORCH_CUDA=cu126 bash setup.sh`: the default torch build (CUDA 12.8) does not support them.

If the Hugging Face download is blocked by a firewall, copy the dataset files to the machine some other way, then run `python download_data.py --from-dir <folder>` (checksums are still verified).

## 2. Run

**SLURM cluster (ALICE3), no separate setup needed:** edit `--account` and `--mail-user` in `run_alice.sbatch`, then `sbatch run_alice.sbatch`. Task 0 runs the one-time setup (with the Pascal torch build), then the 7 default jobs run in parallel as a job array (one P100 each); details are in the file header.

**One GPU machine:** inside tmux on the GPU node:

```bash
bash run_all.sh      # runs the pending jobs one after another; re-run to resume; finished jobs are skipped
```

Default jobs: `s3t_sfda`, `stcgn`, `snd` on IRRG; `dtst`, `stable_st`, `s3t_sfda`, `stcgn` on RGB. Options:

```bash
JOBS="picst:irrg dtst:irrg" bash run_all.sh   # custom list (method:setting)
HOURS=10 bash run_all.sh                      # pause each run at its next evaluation after ~10 h (minimum 0.25); re-run to resume
```

`--setting` is `irrg` (PD IRRG, main) or `rgb` (PD RGB). Methods: `picst`, `picst_v1`, `picst_c0`, `picst_c1`, `dtst`, `snd`, `stable_st`, `s3t_sfda`, `stcgn`.
`snd` is IRRG only (its warm stage is IRRG). A single job: `python run.py --method stcgn --setting irrg`
(St-CGN automatically runs its source warm-up, 2000 updates on source chips, first, then adapts).

## 3. Results to send

```bash
python collect_results.py     # also run automatically after every job in run_all.sh
```

Send `results.zip` (a few KB; no checkpoints). It holds `results/summary.md`, one row per run with status, number of evaluations done, and peak / last mIoU6 (runs still in progress show the curve so far), plus each run's `PEAK_AND_ENDPOINT.md`, `peak_and_endpoint.json` and `RUN_STATE.json` under `results/<setting>/<experiment>/`. Full outputs stay in `runs/<setting>/<experiment>/seed1/`.

Evaluate a checkpoint:

```bash
python run.py --method eval --setting irrg --checkpoint <path/to/checkpoint.pth>
```
