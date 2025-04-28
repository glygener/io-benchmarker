#!/bin/bash

# IO Benchmark Script
# Usage: ./io-benchmark.sh [config_file]
# Default config file i ./io-benchmark.json
#
# Dependencies: 
# - jq
# - fio

# Set default config file path
CONFIG_FILE="./io-benchmark.json"

# Override config file if provided as argument
if [ ! -z "$1" ]; then
  CONFIG_FILE="$1"
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file not found: $CONFIG_FILE"
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is not installed. Please install jq to parse JSON config"
  exit 1
fi

# Function to read from JSON config
get_config() {
  local key="$1"
  local default="$2"
  local value=$(jq -r ".$key // \"\" "$CONFIG_FILE"")

  if [ -z "$value" ] || [ "$value" = "null" ]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# Load configuration
TEST_DIR=$(get_config "test_dir" "/tmp/io_benchmark")
FILE_SIZE=$(get_config "file_size" "1024")
BLOCK_SIZE=$(get_config "block_size" "4k")
NUM_FILES=$(get_config "num_files" "5")
LOG_FILE=$(get_config "log_file" "/var/log/io_benchmark.log")
KEEP_FILES=$(get_config "keep_files" "false")
RUN_SEQUENTIAL=$(get_config "run_sequential" "true")
RUN_RANDOM=$(get_config "run_random" "true")
RUN_FSYNCS=$(get_config "run_fsyncs" "true")
RUN_METADATA=$(get_config "run_metadata" "true")
DATE_FORMAT=$(get_config "date_format" "+%Y-%m-%d %H:%M:%S")

# Create a timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Function to log messages
log_message() {
  local message="$1"
  local date_str=$(date "$DATE_FORMAT")
  echo "[$date_str] $message" | tee -a "$LOG_FILE"
}

# Function to log system information
log_system_info() {
  log_message "===== System Information ====="
  log_message "Hostname: $(hostname)"
  log_message "Kernel: $(uname -r)"
  log_message "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d ':' -f2 | xargs)"
  log_message "Memory: $(free -h | grep 'Mem:' | awk '{print $2}')"
  
  # Disk information
  log_message "Disk information:"
  df -h "$TEST_DIR" | tee -a "$LOG_FILE"
  
  # IO scheduler information
  local disk_device=$(df -P "$TEST_DIR" | awk 'NR==2 {print $1}' | sed -e 's/[0-9]*$//')
  disk_device=$(basename "$disk_device")
  
  if [ -f "/sys/block/$disk_device/queue/scheduler" ]; then
    local scheduler=$(cat "/sys/block/$disk_device/queue/scheduler")
    log_message "IO Scheduler for $disk_device: $scheduler"
  fi
  
  # Check if the directory is on SSD or HDD
  if command -v lsblk &> /dev/null; then
    log_message "Disk type:"
    lsblk -d -o NAME,ROTA | grep $(echo "$disk_device" | sed 's/\/dev\///') | tee -a "$LOG_FILE"
  fi
  
  # Check for RAID configuration
  if [ -f "/proc/mdstat" ]; then
    log_message "RAID configuration:"
    cat /proc/mdstat | tee -a "$LOG_FILE"
  fi
  
  log_message "===== End System Information ====="
}

# Function to prepare test directory
prepare_test_dir() {
  log_message "Preparing test directory: $TEST_DIR"
  
  # Create test directory if it doesn't exist
  if [ ! -d "$TEST_DIR" ]; then
    mkdir -p "$TEST_DIR"
    if [ $? -ne 0 ]; then
      log_message "ERROR: Failed to create test directory"
      exit 1
    fi
  fi
  
  # Clean up old test files
  find "$TEST_DIR" -name "io_benchmark_*" -type f -delete
}

# Function to clean up test files
cleanup_test_files() {
  if [ "$KEEP_FILES" = "false" ]; then
    log_message "Cleaning up test files"
    find "$TEST_DIR" -name "io_benchmark_*" -type f -delete
  else
    log_message "Keeping test files in $TEST_DIR"
  fi
}

# Function to run sequential write test
run_sequential_write_test() {
  local file_path="$TEST_DIR/io_benchmark_seq_write_$TIMESTAMP"
  
  log_message "Running sequential write test (${FILE_SIZE}MB, ${BLOCK_SIZE} blocks)"
  log_message "Command: dd if=/dev/zero of=$file_path bs=$BLOCK_SIZE count=$((FILE_SIZE*1024/${BLOCK_SIZE:0:-1}))"
  
  # Run dd with time to measure duration
  { time dd if=/dev/zero of="$file_path" bs="$BLOCK_SIZE" count=$((FILE_SIZE*1024/${BLOCK_SIZE:0:-1})) conv=fsync oflag=direct; } 2>&1 | tee -a "$LOG_FILE"
  
  # Calculate throughput using stat
  local file_size=$(stat -c %s "$file_path")
  log_message "Actual file size: $file_size bytes"
}

# Function to run sequential read test
run_sequential_read_test() {
  local file_path="$TEST_DIR/io_benchmark_seq_write_$TIMESTAMP"
  
  # Check if the file exists (should have been created by sequential write test)
  if [ ! -f "$file_path" ]; then
    log_message "ERROR: Test file not found for sequential read test"
    return
  fi
  
  log_message "Running sequential read test (${FILE_SIZE}MB, ${BLOCK_SIZE} blocks)"
  log_message "Command: dd if=$file_path of=/dev/null bs=$BLOCK_SIZE"
  
  # Clear cache to ensure accurate read test
  sync
  echo 3 > /proc/sys/vm/drop_caches
  
  # Run dd with time to measure duration
  { time dd if="$file_path" of=/dev/null bs="$BLOCK_SIZE" iflag=direct; } 2>&1 | tee -a "$LOG_FILE"
}

# Function to run random IO test using fio
run_random_io_test() {
  # Check if fio is installed
  if ! command -v fio &> /dev/null; then
    log_message "WARNING: fio is not installed. Skipping random IO tests."
    return
  fi
  
  local test_file="$TEST_DIR/io_benchmark_random_$TIMESTAMP"
  
  log_message "Running random read/write test using fio"
  
  # Create a temporary fio job file
  local fio_job_file="/tmp/fio_job_$TIMESTAMP"
  cat > "$fio_job_file" << EOF
[global]
name=random-rw
filename=$test_file
size=${FILE_SIZE}M
ioengine=libaio
direct=1
sync=0
rw=randrw
bs=$BLOCK_SIZE
rwmixread=70
rwmixwrite=30
iodepth=8
numjobs=4
runtime=30
group_reporting=1

[job1]
name=random-job
EOF
  
  # Run fio
  fio "$fio_job_file" | tee -a "$LOG_FILE"
  
  # Clean up job file
  rm -f "$fio_job_file"
}

# Function to run fsync test
run_fsync_test() {
  log_message "Running fsync test"
  
  local test_file="$TEST_DIR/io_benchmark_fsync_$TIMESTAMP"
  
  # Check if fio is installed
  if ! command -v fio &> /dev/null; then
    log_message "WARNING: fio is not installed. Using dd for basic fsync test."
    # Run a basic fsync test with dd
    { time dd if=/dev/zero of="$test_file" bs=1M count=$((FILE_SIZE/10)) oflag=dsync; } 2>&1 | tee -a "$LOG_FILE"
    return
  fi
  
  # Create a temporary fio job file for fsync test
  local fio_job_file="/tmp/fio_fsync_$TIMESTAMP"
  cat > "$fio_job_file" << EOF
[global]
name=fsync-test
filename=$test_file
size=${FILE_SIZE}M
ioengine=libaio
direct=1
sync=1
fsync=1
fsync_on_close=1
rw=write
bs=4k
numjobs=1
runtime=30
group_reporting=1

[job1]
name=fsync-job
EOF
  
  # Run fio
  fio "$fio_job_file" | tee -a "$LOG_FILE"
  
  # Clean up job file
  rm -f "$fio_job_file"
}

# Function to run metadata test (file creation and deletion)
run_metadata_test() {
  log_message "Running metadata test (file creation and deletion)"
  
  local test_dir="$TEST_DIR/metadata_test_$TIMESTAMP"
  mkdir -p "$test_dir"
  
  # Create many small files
  log_message "Creating 1000 small files"
  { time for i in {1..1000}; do
      touch "$test_dir/file_$i"
  done; } 2>&1 | tee -a "$LOG_FILE"
  
  # List directory
  log_message "Listing directory"
  { time ls -la "$test_dir" > /dev/null; } 2>&1 | tee -a "$LOG_FILE"
  
  # Delete files
  log_message "Deleting 1000 small files"
  { time rm -rf "$test_dir"; } 2>&1 | tee -a "$LOG_FILE"
}

# Main execution starts here
log_message "===== IO Benchmark Started at $(date) ====="
log_message "Configuration:"
log_message "  TEST_DIR: $TEST_DIR"
log_message "  FILE_SIZE: ${FILE_SIZE}MB"
log_message "  BLOCK_SIZE: $BLOCK_SIZE"
log_message "  NUM_FILES: $NUM_FILES"
log_message "  LOG_FILE: $LOG_FILE"

# Log system information
log_system_info

# Prepare test directory
prepare_test_dir

# Run tests based on configuration
if [ "$RUN_SEQUENTIAL" = "true" ]; then
  run_sequential_write_test
  run_sequential_read_test
fi

if [ "$RUN_RANDOM" = "true" ]; then
  run_random_io_test
fi

if [ "$RUN_FSYNCS" = "true" ]; then
  run_fsync_test
fi

if [ "$RUN_METADATA" = "true" ]; then
  run_metadata_test
fi

# Clean up
cleanup_test_files

log_message "===== IO Benchmark Completed at $(date) ====="
log_message "Results saved to $LOG_FILE"

exit 0
