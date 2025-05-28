#!/usr/bin/env bash

# run_all.sh: Run ace0, COLMAP and OpenMVG pipelines in sequence,
#             monitoring each and sleeping between runs.
# Usage: ./run_all.sh [-i interval_in_seconds] -d image_path_glob

INTERVAL=30
IMAGE_GLOB=""

show_help() {
  cat << EOF
Usage: $0 [-i interval_in_seconds] -d image_path_glob

  -i    Sampling interval in seconds (default: $INTERVAL)
  -d    Input image path or glob (e.g. "/path/to/images/*.JPG")
  -h    Show this help message
EOF
  exit 1
}

# parse options
while getopts ":i:d:h" opt; do
  case $opt in
    i) INTERVAL="$OPTARG" ;;
    d) IMAGE_GLOB="$OPTARG" ;;
    h) show_help ;;
    \?) echo "Invalid option: -$OPTARG" >&2; show_help ;;
    :)  echo "Option -$OPTARG requires an argument." >&2; show_help ;;
  esac
done

# require the image‐glob
if [ -z "$IMAGE_GLOB" ]; then
  echo "Error: you must specify -d image_path_glob" >&2
  show_help
fi

# run each pipeline with monitoring
./ace0_0.sh -i "$INTERVAL" -d "$IMAGE_GLOB"
echo "ace0 pipeline completed; sleeping 6 minutes…"
sleep 360

./colmap_0.sh -i "$INTERVAL" -d "$IMAGE_GLOB"
echo "COLMAP pipeline completed; sleeping 6 minutes…"
sleep 360

./openmvg_0.sh -i "$INTERVAL" -d "$IMAGE_GLOB"
echo "OpenMVG pipeline completed."
echo "All pipelines completed successfully."
# End of run_all.sh