# IO Benchmarking Report For Biomarker Dev VM

Started on Wednesday April 30 at 12:50:10 EDT 2025

- [Overall Assessment](#overall-assessment)
- [Configuration](#configuration)
  - [Test Config](#test-config)
  - [VM Config](#vm-config)
- [Benchmarking](#benchmarking)
  - [Sequential Write Test](#sequential-write-test)
  - [Sequential Read Test](#sequential-read-test)
  - [Random IO Test](#random-io-test)
  - [Fsync Test](#fsync-test)
  - [Metadata Test](#metadata-test)

## Overall Assessment

Benchmarks reveal severe performance issues with the storage system:
- Extremely poor write performance (378 KB/s sequential, 2.8 MB/s random)
  - Somewhat strange that random writes perform better than sequential writes
- Write performance is 90+ times slower than reads
- Better (relatively compared to write), but still poor read performance (35.5 MB/s sequential, 6.5 MB/s random)
- Very high latency, especially for wrties (42ms average)
- Poor metadata performance
- Particularly poor performance with fsync operations (only 94 IOPS)

**Root Cause Analysis**:
- The VM NFS mount is experiencing significant bottlenecks, could be due to:
  - Network connectivity limitations or congestion 
  - NFS server resource constraints
  - Innefficient NSG configuration
  - Possible network infrastructure issues between VM and storage

## Configuration

### Test Config

- `TEST_DIR`: /data/shared/repos/io-benchmarker/test_dir
- `FILE_SIZE`: 1024MB
- `BLOCK_SIZE`: 4k
- `NUM_FILES`: 5
- `LOG_FILE`: /data/shared/repos/io-benchmarker/io_benchmarker.log
- `Hostname`: biomarkerkb-vm-dev
- `Kernel`: 4.18.0-553.34.1.el8_10.x86_64
- `CPU`: Intel(R) Xeon(R) Gold 5218R CPU @ 2.10GHz
- `Memory`: 31Gi

### VM Config

**Filesystem**:
| Filesystem | Size | Used | Avail | Use% | Mounted on |
|-|-|-|-|-|-|
| 10.10.0.3:/tank1/biomarkerkb/data/shared | 990G |  143G | 848G | 15% | /data/shared |

## Benchmarking

### Sequential Write Test

- **Description**: 
  - This test measures how quickly our system can save large files by writing 1GB of data sequentially in 4KB blocks
  - Simulates saving large datasets or files
- **Command**:  
```bash
dd if=/dev/zero of=/data/shared/repos/io-benchmarker/test_dir/io_benchmark_seq_write_20250430_125010 bs=4k count=262144
```

**DD Command Output**:

```bash
262144+0 records in
262144+0 records out
1073741824 bytes (1.1 GB, 1.0 GiB) copied, 2842.49 s, 378 kB/s
```

**Time Command Output**:

```bash
real    47m22.500s
user    0m0.618s
sys     0m7.826s
```

**Analysis**:
- 262,144 blocks of 4KB each were successfully written (1GB total)
- Write throughput was only 378 KB/s (extremely slow)
- Total elapsed time took 47 minutes and 22.5 seconds 
- User CPU time was negligible at 0.618 seconds
- System CPU time took 7.826 seconds
- The vast majority of the time was spent waiting for I/O, not CPU processing

### Sequential Read Test

- **Description**:
  - This test measures how quickly our system can read large files by reading the 1GB file created in the previous test
  - Simulates loading datasets or files into applications
- **Command**:
```bash
dd if=/data/shared/repos/io-benchmarker/test_dir/io_benchmark_seq_write_20250430_125010 of=/dev/null bs=4k
```

**DD Command Output**:

```bash
262144+0 records in
262144+0 records out
1073741824 bytes (1.1 GB, 1.0 GiB) copied, 30.2378 s, 35.5 MB/s
```

**Time Command Output**:

```bash
real    0m30.240s
user    0m0.068s
sys     0m1.649s
```

**Analysis**:

- Total elapsed time took 30.24 seconds to read 1GB
- Read throughput was 35.5 MB/s (about 94x faster than write)
- Whie better than write performance, relatively, still would be considered slow for modern storge

### Random IO Test

- **Description**: 
  - A random read/write test using [`fio`](https://github.com/axboe/fio) tool
  - Simulates real-world application behavior where data is read and written in a non-sequential pattern
  - More closely reflects database operations and application behavior

**Fio Command Configuration**:

```bash
random-job: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=8
...
fio-3.19
Starting 4 processes
random-job: Laying out IO file (1 file / 1024MiB)
```

- Test using fio version 3.19
- Random read/write pattern (`randrw`), with 70% reads, 30% writes
- 4KB block size
- Queue depth of 8
- Using 4 parallel processes
- Creating a 1024MiB test file

**Read Performance Results**:
```bash
random-job: (groupid=0, jobs=4): err= 0: pid=1837602: Wed Apr 30 14:27:02 2025
  read: IOPS=1628, BW=6514KiB/s (6670kB/s)(191MiB/30023msec)
    slat (nsec): min=1261, max=125021, avg=5786.32, stdev=5049.79
    clat (usec): min=88, max=526997, avg=1348.02, stdev=10861.95
     lat (usec): min=91, max=527000, avg=1353.94, stdev=10862.00
```

- **IOPS**: 1,628 I/O operations per second
- **Bandwith**: 6.5 MB/s
- **Latency Terms**:
  - `slat`: submission latency (time to submit to kernel)
  - `clat`: completion latency (time from submission to completion)
  - `lat`: total latency (sum of submission and completeion)
- **Latency Analysis**:
  - Average total latency: 1.35ms for reads
  - Maximum latency reached 527ms (very high spike)
  - High standard deviation indicates inconsistent performance

**Read Latency Distrubution**:
```bash
    clat percentiles (usec):
     |  1.00th=[   145],  5.00th=[   176], 10.00th=[   194], 20.00th=[   223],
     | 30.00th=[   245], 40.00th=[   273], 50.00th=[   302], 60.00th=[   343],
     | 70.00th=[   396], 80.00th=[   474], 90.00th=[   627], 95.00th=[   865],
     | 99.00th=[ 18220], 99.50th=[ 47973], 99.90th=[181404], 99.95th=[246416],
     | 99.99th=[358613]
```

- 50% of read operations complete in less than 302μs (relatively good)
- 90% complete in less than 627μs
- 1% take over 18ms, showing occasional very high latency
- 0.01% take over 385ms (worst case, severe outliers)
- Long tail of slow operations is particularly problematic for interactive applications

**Read Bandwith Variability**:
```bash
   bw (  KiB/s): min=  288, max=15456, per=99.16%, avg=6458.32, stdev=1266.41, samples=236
   iops        : min=   72, max= 3864, avg=1614.37, stdev=316.63, samples=236
```

- Bandwith minimum: 288 KB/s, maximum: 15.1 Mb/s
- IOPS minimum: 72, maximum: 3,864
- High variance indicating inconsistent performance
- This inconsistency makes application performance unpredictable

**Write Performance Results**:
```bash
  write: IOPS=703, BW=2816KiB/s (2884kB/s)(82.6MiB/30023msec); 0 zone resets
```

- 703 IOPS (much lower than read)
- 2.8 MB/s bandwith
- Total 82.6MB written in 30 seconds

**Write Latency Analysis**:
```bash
    slat (nsec): min=1415, max=124234, avg=6321.09, stdev=4893.02
    clat (usec): min=1637, max=780231, avg=42308.04, stdev=64117.66
     lat (usec): min=1642, max=780236, avg=42314.50, stdev=64117.65
```

- Average latency is 42.3ms (very high)
- Maximum latency: 780ms (extremely high)
- Much greater standard deviation indicating high inconsistency
- Write latency is approximately 31x higher than read latency

**Write Latency Distrubution**:
```bash
    clat percentiles (msec):
     |  1.00th=[    3],  5.00th=[    9], 10.00th=[   12], 20.00th=[   15],
     | 30.00th=[   17], 40.00th=[   20], 50.00th=[   23], 60.00th=[   27],
     | 70.00th=[   31], 80.00th=[   40], 90.00th=[   93], 95.00th=[  171],
     | 99.00th=[  338], 99.50th=[  401], 99.90th=[  527], 99.95th=[  531],
     | 99.99th=[  743]
```

- 50% of writes take over 23ms (very slow)
- 90% take over 93ms
- 1% take over 338ms
- Much worse than read latencies
- Overall extremely slow, write latency is in human-perceptible range

**Write Bandwith Variability**:
```bash
   bw (  KiB/s): min=  213, max= 6424, per=99.20%, avg=2792.61, stdev=546.77, samples=236
   iops        : min=   51, max= 1606, avg=697.93, stdev=136.73, samples=236
```

- Minimum: 213 KB/s, Maximum: 6.3 MB/s
- IOPS fluctuated between 51 and 1,606
- Continues to show very inconsistent performance

**Overall Latency Distrubution**:
```bash
  lat (usec)   : 100=0.02%, 250=22.13%, 500=35.51%, 750=7.68%, 1000=1.49%
  lat (msec)   : 2=0.45%, 4=1.10%, 10=1.98%, 20=11.70%, 50=12.53%
  lat (msec)   : 100=2.44%, 250=2.13%, 500=0.74%, 750=0.10%, 1000=0.01%
```

- About 65% of operations complete in under 500μs
- About 30% take between 1ms and 100ms
- About 3% take over 100ms

**CPU and System Impact**:
```bash
  cpu          : usr=0.12%, sys=0.42%, ctx=45212, majf=0, minf=76
```

- CPU usage was minimal, confirming storage is the bottleneck
- 45,212 context switches during the test 
- The system mostly waiting for I/O, not processing

```bash
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=100.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.1%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
```

- Queue depth statistics showing the test effectively used `depth=8`

```bash
     issued rwts: total=48890,21136,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=8
```

- Total operations: 48,890 reads, 21,136 writes
- No short of dropped operations

```bash
Run status group 0 (all jobs):
   READ: bw=6514KiB/s (6670kB/s), 6514KiB/s-6514KiB/s (6670kB/s-6670kB/s), io=191MiB (200MB), run=30023-30023msec
  WRITE: bw=2816KiB/s (2884kB/s), 2816KiB/s-2816KiB/s (2884kB/s-2884kB/s), io=82.6MiB (86.6MB), run=30023-30023msec
```

- Summary of read and write performance
- Confirms the performance numbers mentioned above

### Fsync Test

- **Description**: 
  - This test measures how quickly the system can write data and ensure it's safely stored on disk (data durability)
  - Crucial for databases and any application where data integrity is essential

**Fsync Configuration**:

```bash
fsync-job: (g=0): rw=write, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
fio-3.19
Starting 1 process
fsync-job: Laying out IO file (1 file / 1024MiB)
```

- Starting a single process
- Queue depth of 1
- Creating a 1GB test file

**Fsync Performance Results**:
```bash
fsync-job: (groupid=0, jobs=1): err= 0: pid=1838029: Wed Apr 30 14:27:34 2025
  write: IOPS=94, BW=379KiB/s (388kB/s)(11.1MiB/30032msec); 0 zone resets
```

- Only achieved 94 IOPS with fsync enabled
- Bandwith of 379 KB/s
- Only wrote 11.1MB in 30 seconds (extremely slow)
- Would be considered severly inadequate for database operations

**Fsync Latency Analysis**:
```bash
    slat (nsec): min=2620, max=88239, avg=20202.96, stdev=15547.73
    clat (usec): min=1680, max=172467, avg=10513.57, stdev=11639.20
     lat (usec): min=1693, max=172480, avg=10534.17, stdev=11639.92
```

- Average latency of 10.5ms per operation
- Maximum latency of 172ms

**Fsync Latency Distrubution**:
```bash
    clat percentiles (msec):
     |  1.00th=[    3],  5.00th=[    3], 10.00th=[    3], 20.00th=[    3],
     | 30.00th=[    4], 40.00th=[    5], 50.00th=[   11], 60.00th=[   12],
     | 70.00th=[   12], 80.00th=[   13], 90.00th=[   21], 95.00th=[   28],
     | 99.00th=[   66], 99.50th=[   80], 99.90th=[  121], 99.95th=[  163],
     | 99.99th=[  174]
```

- 50% of operations took over 11ms
- 10% took over 21ms
- 1% took over 66ms

**Fsync Bandwith Variability**:
```bash
   bw (  KiB/s): min=  104, max=  640, per=100.00%, avg=381.44, stdev=115.73, samples=59
   iops        : min=   26, max=  160, avg=95.34, stdev=28.96, samples=59
  lat (msec)   : 2=0.98%, 4=38.24%, 10=4.81%, 20=45.54%, 50=8.95%
  lat (msec)   : 100=1.23%, 250=0.25%
```

- Bandwidth fluctuated between 104 KB/s and 640 KB/s
- IOPS between 26 and 160
- Highly variable performance
- Most operations (about 84%) took between 4ms and 20ms

**Sync Operation Analysis**:
```bash
  fsync/fdatasync/sync_file_range:
    sync (nsec): min=34, max=13049, avg=207.14, stdev=331.53
```

- The actual sync operation itself was fast (average 207ns)
- This indicates the bottleneck is in the write operations, not the sync command
- The problem is likely the network filesystem, not the fsync mechanism itself

```bash
    sync percentiles (nsec):
     |  1.00th=[   44],  5.00th=[   56], 10.00th=[   66], 20.00th=[   97],
     | 30.00th=[  105], 40.00th=[  112], 50.00th=[  122], 60.00th=[  133],
     | 70.00th=[  195], 80.00th=[  410], 90.00th=[  474], 95.00th=[  494],
     | 99.00th=[  532], 99.50th=[  572], 99.90th=[ 4192], 99.95th=[ 8032],
     | 99.99th=[12992]
  cpu          : usr=0.12%, sys=0.31%, ctx=2849, majf=0, minf=12
  IO depths    : 1=200.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,2848,0,2847 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1
Run status group 0 (all jobs):
  WRITE: bw=379KiB/s (388kB/s), 379KiB/s-379KiB/s (388kB/s-388kB/s), io=11.1MiB (11.7MB), run=30032-30032msec
```

- Most sync operations completed in under 500ns
- Only a tiny fraction took over 4μs
- Summary confirming 379 KB/s write bandwidth with fsync

### Metadata Test

- **Description**:
  - This test measures how quickly the system can perform file operations like creating and deleting files

**File Creation Performance**:
```bash
Creating 1000 small files

real    0m16.726s
user    0m0.409s
sys     0m0.850s
```

- Creating 1,000 empty files took 16.7 seconds
- About 60 files per second (very slow for metadata operations)
- Very little CPU time used, indicating I/O bottleneck

**File Deletion Performance**:
```bash
Deleting 1000 small files

real    0m9.198s
user    0m0.004s
sys     0m0.097s
```

- Deleting 1,000 files took 9.2 seconds
- About 109 files per second
- Faster than creation but still quite slow for metadata operations 
- Minimal CPU time used
