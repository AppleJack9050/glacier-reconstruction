#!/usr/bin/env bash

# monitor_openmvg.sh: Monitor CPU, RAM, and GPU usage for an OpenMVG SfM pipeline and record its duration
# Usage: ./monitor_openmvg.sh [-i interval_in_seconds] [-o logfile] -d image_path_glob

INTERVAL=30
OUTFILE="monitor_openmvg_0.log"
IMAGE_GLOB=""

show_help() {
  cat << EOF
Usage: $0 [-i interval_in_seconds] [-o logfile] -d image_path_glob

  -i    Sampling interval in seconds (default: $INTERVAL)
  -o    Output CSV file        (default: $OUTFILE)
  -d    Input image path or glob (e.g. "/path/to/JPG/*.JPG")
  -h    Show this help message
EOF
  exit 1
}

# Parse options
while getopts ":i:o:d:h" opt; do
  case $opt in
    i) INTERVAL="$OPTARG" ;;
    o) OUTFILE="$OPTARG" ;;
    d) IMAGE_GLOB="$OPTARG" ;;
    h) show_help ;;
    \?) echo "Invalid option: -$OPTARG" >&2; show_help ;;
    :)  echo "Option -$OPTARG requires an argument." >&2; show_help ;;
  esac
done

# Ensure image glob was provided
if [ -z "$IMAGE_GLOB" ]; then
  echo "Error: you must specify -d image_path_glob" >&2
  show_help
fi

# Record start timestamp
START_TS=$(date +%s)

# Initialize or append CSV file
if [ ! -f "$OUTFILE" ]; then
  echo "timestamp,cpu_percent,mem_percent,gpu_util_percent,gpu_mem_used_mb" > "$OUTFILE"
  echo "Created new log file: $OUTFILE"
else
  echo "Appending to existing log file: $OUTFILE"
fi

# Launch the OpenMVG pipeline in background
(
  cd .. || exit 1
  mkdir -p ./openmvg_workdir

  cd ./openMVG/openMVG_Build/software/SfM || exit 1
  python SfM_SequentialPipeline.py "$IMAGE_GLOB" "../openmvg_workdir"
  cd ../../exp_script || exit 1
) &
PID=$!

# Fetch total GPU memory once
GPU_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)

# Monitoring loop
while kill -0 "$PID" 2>/dev/null; do
  TIMESTAMP=$(date +%s.%N)
  CPU=$(mpstat -P ALL 1 1 | awk 'NR==4 {print $3 "%"}')
  MEM=$(free | awk '/Mem:/ {printf "%.1f%%", $3/$2*100}')

  if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n1)
    GPU_MEM_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -n1)
    GPU_MEM_UTIL=$(( GPU_MEM_USED * 100 / GPU_TOTAL ))
  else
    GPU_UTIL="N/A"
    GPU_MEM_UTIL="N/A"
  fi

  echo "$TIMESTAMP,$CPU,$MEM,${GPU_UTIL}%,${GPU_MEM_UTIL}%" >> "$OUTFILE"
  sleep "$INTERVAL"
done

# Wait for the pipeline to finish
wait "$PID"
EXIT_STATUS=$?
END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))

# Format duration as H:M:S
HMS=$(printf '%02d:%02d:%02d' $((DURATION/3600)) $((DURATION%3600/60)) $((DURATION%60)))

echo "Sequence exited with status: $EXIT_STATUS"
echo "Total duration: ${DURATION}s (${HMS})" >> "$OUTFILE"
