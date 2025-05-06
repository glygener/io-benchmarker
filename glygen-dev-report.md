# IO Benchmarking Report For GlyGen Dev VM

Started on Monday May 5 at 07:42:25 EDT 2025

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

Benchmarks reveal performance issues with the storage system:
- Extremely poor write performance (362 KB/s sequential, 2.54 MiB/s random)
  - Somewhat strange that random writes perform better than sequential writes
- Write performance is 67 times slower than reads
- Better (relatively compared to write), but still poor read performance (24.3 MB/s sequential, 5.99 MB/s random)
- Very high latency, especially for writes (46.2ms average)
- Poor metadata performance
- Particularly poor performance with fsync operations (only 91 IOPS)

**Root Cause Analysis**:
- The VM NFS mount is experiencing significant bottlenecks, could be due to:
  - Network connectivity limitations or congestion 
  - NFS server resource constraints
  - Innefficient NSG configuration
  - Possible network infrastructure issues between VM and storage

## Configuration

### Test Config

- `TEST_DIR`: /home/maria.kim/io-benchmarker/test_dir
- `FILE_SIZE`: 1024MB
- `BLOCK_SIZE`: 4k
- `NUM_FILES`: 5
- `LOG_FILE`: /home/maria.kim/io-benchmarker/io_benchmarker.log
- `Hostname`: glygen-vm-dev
- `Kernel`: 3.10.0-1160.99.1.el7.x86_64
- `CPU`: Intel Core Processor (Broadwell)
- `Memory`: 31Gi

### VM Config

**Filesystem**:
| Filesystem | Size | Used | Avail | Use% | Mounted on |
|-|-|-|-|-|-|
| glygen-nfs:/tank1/data/shared | 6.4T | 4.9T | 1.6T | 77% | /data/shared

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
1073741824 bytes (1.1 GB) copied, 2969.71 s, 362 kB/s
```

**Time Command Output**:

```bash
real	49m29.720s
user	0m0.769s
sys	  0m4.435s
```

**Analysis**:
- 262,144 blocks of 4KB each were successfully written (1.1 GB total)
- Write throughput was only 362 KB/s (extremely slow)
- Total elapsed time was 49 minutes and 29.72 seconds 
- User CPU time was negligible at 0.769 seconds
- System CPU time was 4.435 seconds
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
1073741824 bytes (1.1 GB) copied, 44.1546 s, 24.3 MB/s
```

**Time Command Output**:

```bash
real	0m44.157s
user	0m0.165s
sys	  0m1.603s
```

**Analysis**:

- Total elapsed time was 44.157 seconds to read 1GB
- Read throughput was 24.3 MB/s (about 67x faster than write)
- While relatively better than write performance, still would be considered slow for modern storage

### Random IO Test

- **Description**: 
  - A random read/write test using [`fio`](https://github.com/axboe/fio) tool
  - Simulates real-world application behavior where data is read and written in a non-sequential pattern
  - More closely reflects database operations and application behavior

**Fio Command Configuration**:

```bash
random-job: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=8
...
fio-3.7
Starting 4 processes
random-job: Laying out IO file (1 file / 1024MiB)
```

- Test using fio version 3.7
- Random read/write pattern (`randrw`), with 70% reads, 30% writes
- 4KB block size
- Queue depth of 8
- Using 4 parallel processes
- Creating a 1024MiB test file

**Read Performance Results**:
```bash
random-job: (groupid=0, jobs=4): err= 0: pid=16422: Mon May  5 08:33:41 2025
   read: IOPS=1498, BW=5992KiB/s (6136kB/s)(177MiB/30293msec)
    slat (usec): min=2, max=1273, avg=10.29, stdev=16.98
    clat (usec): min=2, max=515304, avg=1270.49, stdev=10199.18
     lat (usec): min=121, max=515312, avg=1281.60, stdev=10199.18
```

- **IOPS**: 1,498 I/O operations per second
- **Bandwith**: 5.99 MB/s
- **Latency Terms**:
  - `slat`: submission latency (time to submit to kernel)
  - `clat`: completion latency (time from submission to completion)
  - `lat`: total latency (sum of submission and completeion)
- **Latency Analysis**:
  - Average total latency: 1.28ms for reads
  - Maximum latency reached 515ms (very high spike)
  - High standard deviation indicates inconsistent performance

**Read Latency Distrubution**:
```bash
    clat percentiles (usec):
     |  1.00th=[   167],  5.00th=[   208], 10.00th=[   235], 20.00th=[   269],
     | 30.00th=[   306], 40.00th=[   343], 50.00th=[   379], 60.00th=[   424],
     | 70.00th=[   478], 80.00th=[   562], 90.00th=[   717], 95.00th=[   971],
     | 99.00th=[ 16581], 99.50th=[ 31065], 99.90th=[175113], 99.95th=[244319],
     | 99.99th=[396362]
```

- 50% of read operations complete in less than 379μs (relatively good)
- 90% complete in less than 717μs
- 1% take over 17.5ms, showing occasional very high latency
- 0.01% take over 396ms (worst case, severe outliers)
- Long tail of slow operations is particularly problematic for interactive applications

**Read Bandwith Variability**:
```bash
   bw (  KiB/s): min=   64, max= 3528, per=25.24%, avg=1512.53, stdev=1106.89, samples=240
   iops        : min=   16, max=  882, avg=378.10, stdev=276.74, samples=240
```

- Bandwith minimum: 64 KiB/s, maximum: 3.45 Mib/s
- IOPS minimum: 16, maximum: 882
- High variance indicating inconsistent performance
- This inconsistency makes application performance unpredictable

**Write Performance Results**:
```bash
  write: IOPS=650, BW=2603KiB/s (2666kB/s)(77.0MiB/30293msec)
```

- 650 IOPS (a bit lower than read)
- 2.54 MiB/s bandwith
- Total 77MiB written in 30 seconds

**Write Latency Analysis**:
```bash
    slat (usec): min=2, max=721, avg=11.49, stdev=17.60
    clat (usec): min=1911, max=857698, avg=46164.01, stdev=69859.17
     lat (usec): min=1922, max=857708, avg=46176.30, stdev=69859.39
```

- Average latency is 46.2ms (very high)
- Maximum latency: 858ms (extremely high)
- Much greater standard deviation indicating high inconsistency
- Write latency is approximately 36x higher than read latency

**Write Latency Distrubution**:
```bash
    clat percentiles (msec):
     |  1.00th=[    4],  5.00th=[    7], 10.00th=[   11], 20.00th=[   15],
     | 30.00th=[   17], 40.00th=[   20], 50.00th=[   24], 60.00th=[   28],
     | 70.00th=[   32], 80.00th=[   46], 90.00th=[  108], 95.00th=[  194],
     | 99.00th=[  359], 99.50th=[  435], 99.90th=[  518], 99.95th=[  567],
     | 99.99th=[  860]
```

- 50% of writes take over 24ms (very slow)
- 90% take over 108ms
- 1% take over 359ms
- Much worse than read latencies
- Overall extremely slow, write latency is in human-perceptible range

**Write Bandwith Variability**:
```bash
   bw (  KiB/s): min=   55, max= 1512, per=25.20%, avg=656.02, stdev=476.03, samples=240
   iops        : min=   13, max=  378, avg=163.97, stdev=119.02, samples=240
```

- Minimum: 55 KiB/s, Maximum: 1.5 MiB/s
- IOPS fluctuated between 13 and 378
- Continues to show very inconsistent performance

**Overall Latency Distrubution**:
```bash
  lat (usec)   : 100=0.01%, 250=9.83%, 500=41.17%, 750=12.43%, 1000=2.97%
  lat (msec)   : 2=1.03%, 4=1.02%, 10=2.46%, 20=10.74%, 50=12.52%
  lat (msec)   : 100=2.49%, 250=2.30%, 500=0.98%, 750=0.06%, 1000=0.01%
```

- About 59% of operations complete in under 500μs
- About 30% take between 1ms and 100ms
- About 3% take over 100ms

**CPU and System Impact**:
```bash
  cpu          : usr=0.24%, sys=0.83%, ctx=41738, majf=0, minf=125
```

- CPU usage was minimal, confirming storage is the bottleneck
- 41,738 context switches during the test 
- The system mostly waiting for I/O, not processing

```bash
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=100.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.1%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
```

- Queue depth statistics showing the test effectively used `depth=8`

```bash
     issued rwts: total=45381,19714,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=8
```

- Total operations: 45,381 reads, 19,714 writes
- No short of dropped operations

```bash
Run status group 0 (all jobs):
   READ: bw=5992KiB/s (6136kB/s), 5992KiB/s-5992KiB/s (6136kB/s-6136kB/s), io=177MiB (186MB), run=30293-30293msec
  WRITE: bw=2603KiB/s (2666kB/s), 2603KiB/s-2603KiB/s (2666kB/s-2666kB/s), io=77.0MiB (80.7MB), run=30293-30293msec
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
fio-3.7
Starting 1 process
fsync-job: Laying out IO file (1 file / 1024MiB)
```

- Starting a single process
- Queue depth of 1
- Creating a 1GB test file

**Fsync Performance Results**:
```bash
fsync-job: (groupid=0, jobs=1): err= 0: pid=16463: Mon May  5 08:34:12 2025
  write: IOPS=91, BW=365KiB/s (374kB/s)(10.7MiB/30002msec)
```

- Only achieved 91 IOPS with fsync enabled
- Bandwith of 365 KiB/s
- Only wrote 10.7MiB in 30 seconds (extremely slow)
- Would be considered severly inadequate for database operations

**Fsync Latency Analysis**:
```bash
    slat (nsec): min=6128, max=64584, avg=13040.29, stdev=6537.37
    clat (usec): min=1489, max=402763, avg=10940.92, stdev=17068.35
     lat (usec): min=1503, max=402776, avg=10954.83, stdev=17069.16
```

- Average latency of 10.95ms per operation
- Maximum latency of 403ms

**Fsync Latency Distrubution**:
```bash
    clat percentiles (usec):
     |  1.00th=[  1942],  5.00th=[  2147], 10.00th=[  2311], 20.00th=[  2606],
     | 30.00th=[  2999], 40.00th=[  3523], 50.00th=[ 10421], 60.00th=[ 11076],
     | 70.00th=[ 11600], 80.00th=[ 13042], 90.00th=[ 20317], 95.00th=[ 27657],
     | 99.00th=[ 70779], 99.50th=[ 94897], 99.90th=[238027], 99.95th=[320865],
     | 99.99th=[404751]
```

- 50% of operations took over 10s
- 10% took over 20s
- 1% took over 70s

**Fsync Bandwith Variability**:
```bash
   bw (  KiB/s): min=    8, max=  624, per=100.00%, avg=364.55, stdev=156.51, samples=60
   iops        : min=    2, max=  156, avg=91.07, stdev=39.16, samples=60
  lat (msec)   : 2=1.97%, 4=40.72%, 10=4.28%, 20=42.47%, 50=8.70%
  lat (msec)   : 100=1.39%, 250=0.40%, 500=0.07%
```

- Bandwidth fluctuated between 8 KiB/s and 624 KiB/s
- IOPS between 2 and 156
- Highly variable performance
- Most operations (about 89%) took between 2ms and 20ms

**Sync Operation Analysis**:
```bash
  fsync/fdatasync/sync_file_range:
    sync (nsec): min=490, max=30940, avg=817.17, stdev=1315.84
```

- The actual sync operation itself was fast (average 817ns)
- This indicates the bottleneck is in the write operations, not the sync command
- The problem is likely the network filesystem, not the fsync mechanism itself

```bash
    sync percentiles (nsec):
     |  1.00th=[  502],  5.00th=[  556], 10.00th=[  580], 20.00th=[  596],
     | 30.00th=[  604], 40.00th=[  620], 50.00th=[  636], 60.00th=[  652],
     | 70.00th=[  676], 80.00th=[  740], 90.00th=[ 1320], 95.00th=[ 1400],
     | 99.00th=[ 1528], 99.50th=[ 9280], 99.90th=[22144], 99.95th=[27520],
     | 99.99th=[30848]
  cpu          : usr=0.12%, sys=0.20%, ctx=2740, majf=0, minf=29
  IO depths    : 1=200.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,2736,0,2735 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1
Run status group 0 (all jobs):
  WRITE: bw=365KiB/s (374kB/s), 365KiB/s-365KiB/s (374kB/s-374kB/s), io=10.7MiB (11.2MB), run=30002-30002msec
```

- Most sync operations (95%) completed in under 1.4 μs
- The 99.5th percentile jumped to 9.28 μs, and the worst 0.01% reached up to 30.8 μs
- Summary confirming 365 KiB/s write bandwidth with fsync

### Metadata Test

- **Description**:
  - This test measures how quickly the system can perform file operations like creating and deleting files

**File Creation Performance**:
```bash
Creating 1000 small files

real	0m17.776s
user	0m0.477s
sys	0m1.057s
```

- Creating 1,000 empty files took 17.8 seconds
- About 56 files per second (very slow for metadata operations)
- Very little CPU time used, indicating I/O bottleneck

**File Deletion Performance**:
```bash
Deleting 1000 small files

real	0m8.410s
user	0m0.007s
sys	0m0.082s
```

- Deleting 1,000 files took 8.4 seconds
- About 119 files per second
- Faster than creation but still quite slow for metadata operations 
- Minimal CPU time used
