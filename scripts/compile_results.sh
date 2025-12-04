#!/usr/bin/env bash
set -euo pipefail

# -----------------------
# Run from: repo/scripts/
# -----------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

SAMPLESHEET="${REPO_ROOT}/scripts/rna_kinx_samplesheet.csv"

# Override if you want:
#   QC_BASE_DIR=/path/to/results/qc_reports OUTPUT_FILE=out.tsv ./ccs_reads_table.sh
QC_BASE_DIR="${QC_BASE_DIR:-/scratch/pawsey0964/lhuet/rna_kinnex/PACB_251117_LAAMD/results/qc_reports}"
OUTPUT_FILE="${OUTPUT_FILE:-rna_read_counts.tsv}"

[[ -f "$SAMPLESHEET" ]] || { echo "ERROR: samplesheet not found: $SAMPLESHEET" >&2; exit 1; }
[[ -d "$QC_BASE_DIR" ]] || { echo "ERROR: QC base dir not found: $QC_BASE_DIR" >&2; exit 1; }

# -----------------------
# Map: samples_in_pool (col 6) -> sequencing_sample_id (col 2)
# -----------------------
RUNMAP_TSV="$(
  awk -F',' 'NR>1{
    run=$2; key=$6
    gsub(/\r/, "", run); gsub(/\r/, "", key)
    gsub(/^[ \t"]+|[ \t"]+$/, "", run)
    gsub(/^[ \t"]+|[ \t"]+$/, "", key)
    if (key!="") print key "\t" run
  }' "$SAMPLESHEET"
)"

lookup_runid() {
  local key="$1"
  awk -v k="$key" -F'\t' '$1==k{print $2; exit}' <<< "$RUNMAP_TSV"
}

# -----------------------
# Output
# -----------------------
printf "rna_tube_id\trna_tube_id_2\tread_count\trun_id\n" > "$OUTPUT_FILE"

shopt -s nullglob
for d in "$QC_BASE_DIR"/*_qc_reports/; do
  [[ -d "$d" ]] || continue
  dir="$(basename "${d%/}")"

  # -----------------------
  # Parse tube IDs from the qc_reports directory name
  # rna1 = first *_KL or *_KL2
  # rna2 = second *_KL or *_KL2 if next token starts with OG
  # -----------------------
  read -r rna1 rna2 < <(awk -v s="$dir" 'BEGIN{
    n = split(s, a, "_")

    r1 = a[1]
    i = 2
    while (i <= n) {
      r1 = r1 "_" a[i]
      if (a[i] == "KL" || a[i] == "KL2") { i++; break }
      i++
    }

    r2 = ""
    if (i <= n && a[i] ~ /^OG/) {
      r2 = a[i]
      i++
      while (i <= n) {
        r2 = r2 "_" a[i]
        if (a[i] == "KL" || a[i] == "KL2") break
        i++
      }
    }

    print r1, r2
  }')

  [[ "$rna2" == "$rna1" ]] && rna2=""

  # -----------------------
  # Find CCS report JSON
  # -----------------------
  json="$d/ccs.report.json"
  if [[ ! -f "$json" ]]; then
    json="$(ls -1 "$d"/*.ccs.report.json 2>/dev/null | head -n 1 || true)"
  fi

  # -----------------------
  # Extract read count (ccs2.number_of_ccs_reads)
  # -----------------------
  reads="NA"
  if [[ -n "${json:-}" && -f "$json" ]]; then
    reads="$(awk '
      found_id && /"value"[[:space:]]*:/ {
        if (match($0, /"value"[[:space:]]*:[[:space:]]*([0-9]+)/, m)) print m[1];
        exit
      }
      /"id"[[:space:]]*:[[:space:]]*"ccs2\.number_of_ccs_reads"/ { found_id=1 }
    ' "$json")"
    [[ -n "${reads:-}" ]] || reads="NA"
  fi

  # -----------------------
  # Lookup run_id from samplesheet using rna1
  # -----------------------
  run_id="$(lookup_runid "$rna1")"
  [[ -n "${run_id:-}" ]] || run_id="NA"

  printf "%s\t%s\t%s\t%s\n" "$rna1" "$rna2" "$reads" "$run_id" >> "$OUTPUT_FILE"
done

echo "Wrote: $OUTPUT_FILE" >&2
