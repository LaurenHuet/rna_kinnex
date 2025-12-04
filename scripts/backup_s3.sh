#!/usr/bin/env bash
set -euo pipefail

RESULTS_DIR="${RESULTS_DIR:-/scratch/pawsey0964/lhuet/rna_kinnex/PACB_251117_LAAMD/results}"
DRY_RUN="${DRY_RUN:-1}"   # default dry-run

og_dir_from_name() {
  local name="$1"
  if [[ "$name" =~ ^OG([0-9]+) ]]; then
    printf "OG%s" "${BASH_REMATCH[1]}"
  else
    printf ""
  fi
}

do_mkdir() {
  local path="$1"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'mkdir -p %q\n' "$path"
  else
    mkdir -p "$path"
  fi
}

do_mv() {
  local src="$1"
  local dest="$2"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'mv %q %q\n' "$src" "$dest"
  else
    mv "$src" "$dest"
  fi
}

echo "RESULTS_DIR: $RESULTS_DIR" >&2
echo "DRY_RUN:     $DRY_RUN (1=print only, 0=actually move)" >&2
[[ -d "$RESULTS_DIR" ]] || { echo "ERROR: RESULTS_DIR not found: $RESULTS_DIR" >&2; exit 1; }

ISO_DIR="$RESULTS_DIR/isoseq_refine"
QC_BASE="$RESULTS_DIR/qc_reports"

# 1) Move IsoSeq refine outputs -> results/OGNN/rna/
if [[ -d "$ISO_DIR" ]]; then
  shopt -s nullglob
  for f in \
    "$ISO_DIR"/*.flnc.bam \
    "$ISO_DIR"/*.flnc.consensusreadset.xml
  do
    base="$(basename "$f")"
    og_dir="$(og_dir_from_name "$base")"
    [[ -n "$og_dir" ]] || { echo "WARN: can't parse OG from $base (skip)" >&2; continue; }

    outdir="$RESULTS_DIR/$og_dir/rna"
    do_mkdir "$outdir"
    do_mv "$f" "$outdir/"
  done
else
  echo "WARN: missing $ISO_DIR (skipping isoseq_refine)" >&2
fi

# 2) Move QC report dirs -> results/OGNN/rna/<sample_qc_reports_dir>/
if [[ -d "$QC_BASE" ]]; then
  shopt -s nullglob
  for d in "$QC_BASE"/*_qc_reports; do
    [[ -d "$d" ]] || continue
    base="$(basename "$d")"
    og_dir="$(og_dir_from_name "$base")"
    [[ -n "$og_dir" ]] || { echo "WARN: can't parse OG from $base (skip)" >&2; continue; }

    parent="$RESULTS_DIR/$og_dir/rna"
    do_mkdir "$parent"
    do_mv "$d" "$parent/"
  done
else
  echo "WARN: missing $QC_BASE (skipping qc_reports)" >&2
fi


# -----------------------
# 3) Bundle OG* dirs into RESULTS_DIR/backup and upload to S3
# -----------------------
BACKUP_DIR="$RESULTS_DIR/backup"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "mkdir -p $BACKUP_DIR" >&2
  echo "mv $RESULTS_DIR/OG* $BACKUP_DIR/" >&2
  echo "(cd $BACKUP_DIR && rclone copy . s3:oceanomics/OceanGenomes/pacbio-sra --dry-run)" >&2
else
  mkdir -p "$BACKUP_DIR"

  # Move OG* directories created under RESULTS_DIR (not from your scripts dir)
  shopt -s nullglob
  og_dirs=( "$RESULTS_DIR"/OG* )
  if (( ${#og_dirs[@]} > 0 )); then
    mv "${og_dirs[@]}" "$BACKUP_DIR"/
  else
    echo "WARN: no $RESULTS_DIR/OG* directories found to move" >&2
  fi
    cd "$BACKUP_DIR"
    wait
  # Upload ONLY the staged backup folder contents
  rclone copy . s3:oceanomics/OceanGenomes/pacbio-sra
fi