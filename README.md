# IO Benchmark Script

A flexible, configurable bash script for benchmarking IO performance on Linux servers. This tool provides insights into disk read/write speeds, fsync performance, and metadata operations.

## Overview

This script conducts various IO benchmarks and logs the results, making it ideal for:

- Monitoring IO performance over time
- Diagnosing slow disk performance
- Comparing IO performance across different servers or configurations
- Establishing baseline performance metrics

## Features

- **Sequential read/write tests** using `dd` with configurable block sizes and file sizes
- **Random IO tests** using `fio` (if installed)
- **fsync performance testing** to measure persistence latency
- **Metadata operation testing** (file creation, listing, and deletion)
- **Comprehensive system information logging** (CPU, memory, disk type, IO scheduler, etc.)
- **JSON configuration** for easy customization and reuse
- **Detailed logging** with timestamps and performance metrics

## Requirements

- Bash shell
- `jq` for JSON parsing
- `fio` (optional, for random IO and advanced fsync tests)
- Root privileges (recommended for dropping caches and accurate testing)

## Usage

Run with the default configuration file:

```bash
./io-benchmark.sh
```

Specify an alternative configuration file:

```bash
./io-benchmark.sh /path/to/custom_config.json
```

### Setting Up a Cron Job

To schedule regular benchmarks, add an entry to your crontab:

```bash
# Run daily at 3:00 AM
0 3 * * * /path/to/io_benchmark.sh /path/to/io_benchmark.json >> /var/log/io_benchmark_cron.log 2>&1
```

## Configuration

| Option           | Description                                     | Default                           |
| ---------------- | ----------------------------------------------- | --------------------------------- |
| `test_dir`       | Directory where benchmark files will be created | `~/io_benchmark/`                 |
| `file_size`      | Size of test files in MB                        | `1024` (1GB)                      |
| `block_size`     | Block size for IO operations                    | `4k`                              |
| `num_files`      | Number of files for parallel tests              | `5`                               |
| `log_file`       | Path to the log file                            | `~/io_benchmark/io_benchmark.log` |
| `keep_files`     | Whether to keep test files after benchmarking   | `false`                           |
| `run_sequential` | Run sequential read/write tests                 | `true`                            |
| `run_random`     | Run random IO tests                             | `true`                            |
| `run_fsyncs`     | Run fsync performance tests                     | `true`                            |
| `run_metadata`   | Run metadata operation tests                    | `true`                            |
| `date_format`    | Date format for log timestamps                  | `+%Y-%m-%d %H:%M:%S`              |

## Test Types

### Sequential Read/Write Tests

Uses `dd` to measure raw sequential read/write performance:

- Write test: Writes a file of specified size using specified block size
- Read test: Reads the same file back with cache dropped to ensure accurate results

### Random IO Tests

Uses `fio` to simulate realistic workloads with mixed random reads and writes:

- 70% read, 30% write mix
- Multiple parallel jobs
- Direct IO to bypass cache
- Configurable runtime (30 seconds by default)

### fsync Tests

Measures how quickly data can be persisted to stable storage:

- Uses fio with fsync enabled if available
- Falls back to dd with dsync flag if fio is not installed

### Metadata Tests

Benchmarks file system metadata operations:

- Creates 1000 small files
- Lists the directory contents
- Deletes all files

## Log Format

The benchmark logs detailed information for each test, including:

- System information (CPU, memory, disk type, etc.)
- Test parameters (file size, block size, etc.)
- Test results with timing information
- Throughput metrics where available

## Analyzing Results

The log file contains all benchmark results. You can extract specific metrics for analysis:

```bash
# Extract sequential write speeds
grep -A 10 "sequential write test" /var/log/io_benchmark.log

# Extract random IO results
grep -A 20 "random read/write test" /var/log/io_benchmark.log
```
