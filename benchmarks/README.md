# `prometheus-tcl` benchmarks

Inspired by the benchmarking suite included with the [C++ library `prometheus-cpp`](https://github.com/jupp0r/prometheus-cpp), this folder contains benchmarks for the `prometheus-tcl` package.

Benchmarks are defined use the [`tcllib` bench package](https://github.com/tcltk/tcllib/tree/master/modules/bench)'s format.  

A script, `run_benchmarks.tcl` is provided for actually running the benchmarks defined in `.bench` files.  

It takes a few of the arguments that can be passed to `bench::run` along with arguments for controlling which benchmark files get executed.

When run without arguments it benchmarks every `.bench` file in this directory and outputs the results to `stdout` in `bench`'s text format.

<details>
  <summary>run_benchmarks.tcl command-line arguments</summary>

```
run_benchmarks : ./run_benchmarks.tcl ?options?
 -csvOutput           Whether to output results in CSV format (default is text format)
 -iterations value    Number of iterations for each execution of a benchmark <1000>
 -match value         Glob pattern of benchmark descriptions to run ("" means all patterns) <>
 -rmatch value        Regular expression pattern of benchmark descriptions to run ("" means all patterns) <>
 -files value         Space-separated list of files with benchmarks (defaults to all *.bench files) <>
 -verbose             Whether to emit verbose output during benchmark execution
 --                   Forcibly stop option processing
 -help                Print this message
 -?                   Print this message
```

</details>

# Benchmarks 

The benchmarks cover operations on each metric type (counter, gauge, histogram and summary) along with the time to collect metrics, i.e., convert them into Prometheus' text format.

There are separate benchmarks for the public API and the TclOO interface.

Collection benchmarks only use the public API since the collection proc is the same regardless of how the metric objects were created.

## Benchmark Scenarios Provided

Excluding histograms, all metric types are tested using 0, 1, 4, 8, and 16 labels.  

For TclOO benchmarks, direct object access, which captures the return value of the `labels` method on `MetricFamily` objects, is benchmarked against using the `labels` method.

### Counter

- Increment a counter 

- Create a new counter

### Gauge

- Increment a gauge

- Decrement a gauge

- Set a gauge to a specific value

- Set a gauge to the current time

- Create a new gauge

### Histogram

- Observe a histogram with 1, 4, 8, 64, 512, and 4096 buckets

### Summary

- Observe a summary

### Collection

Collect 1, 8, 64, 512, 4096 metric samples where a sample is a single line for a metric in Prometheus' text format, i.e., not a comment.

Collection is also benchmarked in a multi-threaded setting.

## Results

Find the results of running the benchmarks below.  All timing given in microseconds. 1000 iterations each.

<details>
  <summary>Public API Benchmarks</summary>

```
 1: 8.6.9 /usr/bin/tclsh8.6

+----+----------------------------------------------------------------------+-------+
|    | INTERP                                                               |     1 |
+----+----------------------------------------------------------------------+-------+
|  1 | Create a counter with 0 labels using public API                      | 26.00 |
|  2 | Create a counter with 1 labels using public API                      | 20.00 |
|  3 | Create a counter with 4 labels using public API                      | 21.00 |
|  4 | Create a counter with 8 labels using public API                      | 22.00 |
|  5 | Create a counter with 16 labels using public API                     | 25.00 |
|  6 | Create a gauge with 0 labels using the public API                    | 25.00 |
|  7 | Create a gauge with 1 labels using the public API                    | 20.00 |
|  8 | Create a gauge with 4 labels using the public API                    | 21.00 |
|  9 | Create a gauge with 8 labels using the public API                    | 22.00 |
| 10 | Create a gauge with 16 labels using the public API                   | 26.00 |
| 11 | Create a summary with 0 labels using the public API                  | 26.00 |
| 12 | Create a summary with 1 labels using the public API                  | 26.00 |
| 13 | Create a summary with 4 labels using the public API                  | 24.00 |
| 14 | Create a summary with 8 labels using the public API                  | 36.00 |
| 15 | Create a summary with 16 labels using the public API                 | 29.00 |
| 16 | Create histogram with 0 labels with 1 buckets using the public API   | 33.00 |
| 17 | Create histogram with 0 labels with 2 buckets using the public API   | 33.00 |
| 18 | Create histogram with 0 labels with 4 buckets using the public API   | 33.00 |
| 19 | Create histogram with 0 labels with 8 buckets using the public API   | 34.00 |
| 20 | Create histogram with 0 labels with 16 buckets using the public API  | 36.00 |
| 21 | Create histogram with 0 labels with 32 buckets using the public API  | 40.00 |
| 22 | Decrement a gauge with 0 labels using the public API                 |  4.67 |
| 23 | Decrement a gauge with 1 labels using the public API                 |  4.60 |
| 24 | Decrement a gauge with 4 labels using the public API                 |  4.70 |
| 25 | Decrement a gauge with 8 labels using the public API                 |  4.87 |
| 26 | Decrement a gauge with 16 labels using the public API                |  5.29 |
| 27 | Increment a counter with 0 labels using public API                   |  4.51 |
| 28 | Increment a counter with 1 labels using public API                   |  5.03 |
| 29 | Increment a counter with 4 labels using public API                   |  5.09 |
| 30 | Increment a counter with 8 labels using public API                   |  4.94 |
| 31 | Increment a counter with 16 labels using public API                  |  5.56 |
| 32 | Increment a gauge with 0 labels using the public API                 |  4.65 |
| 33 | Increment a gauge with 1 labels using the public API                 |  4.65 |
| 34 | Increment a gauge with 4 labels using the public API                 |  4.62 |
| 35 | Increment a gauge with 8 labels using the public API                 |  4.93 |
| 36 | Increment a gauge with 16 labels using the public API                |  5.31 |
| 37 | Observe a summary with 0 labels using the public API                 |  3.00 |
| 38 | Observe a summary with 1 labels using the public API                 |  3.00 |
| 39 | Observe a summary with 4 labels using the public API                 |  4.00 |
| 40 | Observe a summary with 8 labels using the public API                 |  3.00 |
| 41 | Observe a summary with 16 labels using the public API                |  6.00 |
| 42 | Observe histogram with 0 labels with 1 buckets using the public API  |  4.00 |
| 43 | Observe histogram with 0 labels with 2 buckets using the public API  |  4.00 |
| 44 | Observe histogram with 0 labels with 4 buckets using the public API  |  4.00 |
| 45 | Observe histogram with 0 labels with 8 buckets using the public API  |  4.00 |
| 46 | Observe histogram with 0 labels with 16 buckets using the public API |  4.00 |
| 47 | Observe histogram with 0 labels with 32 buckets using the public API |  5.00 |
| 48 | Set to current time on a gauge with 0 labels using the public API    |  3.29 |
| 49 | Set to current time on a gauge with 1 labels using the public API    |  3.53 |
| 50 | Set to current time on a gauge with 4 labels using the public API    |  3.57 |
| 51 | Set to current time on a gauge with 8 labels using the public API    |  3.79 |
| 52 | Set to current time on a gauge with 16 labels using the public API   |  3.95 |
| 53 | Set value on a gauge with 0 labels using the public API              |  3.00 |
| 54 | Set value on a gauge with 1 labels using the public API              |  3.00 |
| 55 | Set value on a gauge with 4 labels using the public API              |  3.00 |
| 56 | Set value on a gauge with 8 labels using the public API              |  3.00 |
| 57 | Set value on a gauge with 16 labels using the public API             |  4.00 |
+----+----------------------------------------------------------------------+-------+
```
</details>

<details>
  <summary>TclOO Benchmarks</summary>

```
 1: 8.6.9 /usr/bin/tclsh8.6

+----+----------------------------------------------------------------------------------+-------+
|    | INTERP                                                                           |     1 |
+----+----------------------------------------------------------------------------------+-------+
|  1 | Create a counter with 0 labels using TclOO                                       | 18.00 |
|  2 | Create a counter with 1 labels using TclOO                                       | 12.00 |
|  3 | Create a counter with 4 labels using TclOO                                       | 14.00 |
|  4 | Create a counter with 8 labels using TclOO                                       | 15.00 |
|  5 | Create a counter with 16 labels using TclOO                                      | 19.00 |
|  6 | Create a gauge with 0 labels using TclOO                                         | 19.00 |
|  7 | Create a gauge with 1 labels using TclOO                                         | 14.00 |
|  8 | Create a gauge with 4 labels using TclOO                                         | 15.00 |
|  9 | Create a gauge with 8 labels using TclOO                                         | 17.00 |
| 10 | Create a gauge with 16 labels using TclOO                                        | 20.00 |
| 11 | Create a summary with 0 labels using TclOO                                       | 18.00 |
| 12 | Create a summary with 1 labels using TclOO                                       | 12.00 |
| 13 | Create a summary with 4 labels using TclOO                                       | 14.00 |
| 14 | Create a summary with 8 labels using TclOO                                       | 16.00 |
| 15 | Create a summary with 16 labels using TclOO                                      | 19.00 |
| 16 | Create histogram with 0 labels with 1 buckets using TclOO                        | 23.00 |
| 17 | Create histogram with 0 labels with 2 buckets using TclOO                        | 24.00 |
| 18 | Create histogram with 0 labels with 4 buckets using TclOO                        | 24.00 |
| 19 | Create histogram with 0 labels with 8 buckets using TclOO                        | 25.00 |
| 20 | Create histogram with 0 labels with 16 buckets using TclOO                       | 26.00 |
| 21 | Create histogram with 0 labels with 32 buckets using TclOO                       | 29.00 |
| 22 | Decrement a gauge with 0 labels using direct object access                       |  0.91 |
| 23 | Decrement a gauge with 0 labels using MetricFamily labels method                 |  1.61 |
| 24 | Decrement a gauge with 1 labels using direct object access                       |  0.91 |
| 25 | Decrement a gauge with 1 labels using MetricFamily labels method                 |  1.68 |
| 26 | Decrement a gauge with 4 labels using direct object access                       |  0.92 |
| 27 | Decrement a gauge with 4 labels using MetricFamily labels method                 |  1.82 |
| 28 | Decrement a gauge with 8 labels using direct object access                       |  0.91 |
| 29 | Decrement a gauge with 8 labels using MetricFamily labels method                 |  1.87 |
| 30 | Decrement a gauge with 16 labels using direct object access                      |  0.85 |
| 31 | Decrement a gauge with 16 labels using MetricFamily labels method                |  2.17 |
| 32 | Increment a counter with 0 labels using direct object access                     |  0.91 |
| 33 | Increment a counter with 0 labels using MetricFamily labels method               |  1.60 |
| 34 | Increment a counter with 1 labels using direct object access                     |  0.90 |
| 35 | Increment a counter with 1 labels using MetricFamily labels method               |  1.73 |
| 36 | Increment a counter with 4 labels using direct object access                     |  0.90 |
| 37 | Increment a counter with 4 labels using MetricFamily labels method               |  1.85 |
| 38 | Increment a counter with 8 labels using direct object access                     |  0.90 |
| 39 | Increment a counter with 8 labels using MetricFamily labels method               |  1.99 |
| 40 | Increment a counter with 16 labels using direct object access                    |  0.90 |
| 41 | Increment a counter with 16 labels using MetricFamily labels method              |  2.33 |
| 42 | Increment a gauge with 0 labels using direct object access                       |  0.85 |
| 43 | Increment a gauge with 0 labels using MetricFamily labels method                 |  1.53 |
| 44 | Increment a gauge with 1 labels using direct object access                       |  0.85 |
| 45 | Increment a gauge with 1 labels using MetricFamily labels method                 |  1.75 |
| 46 | Increment a gauge with 4 labels using direct object access                       |  0.92 |
| 47 | Increment a gauge with 4 labels using MetricFamily labels method                 |  1.85 |
| 48 | Increment a gauge with 8 labels using direct object access                       |  0.90 |
| 49 | Increment a gauge with 8 labels using MetricFamily labels method                 |  1.96 |
| 50 | Increment a gauge with 16 labels using direct object access                      |  0.91 |
| 51 | Increment a gauge with 16 labels using MetricFamily labels method                |  2.20 |
| 52 | Observe a summary with 0 labels using direct object access                       |  1.00 |
| 53 | Observe a summary with 0 labels using MetricFamily labels method                 |  1.00 |
| 54 | Observe a summary with 1 labels using direct object access                       |  1.00 |
| 55 | Observe a summary with 1 labels using MetricFamily labels method                 |  1.00 |
| 56 | Observe a summary with 4 labels using direct object access                       |  1.00 |
| 57 | Observe a summary with 4 labels using MetricFamily labels method                 |  2.00 |
| 58 | Observe a summary with 8 labels using direct object access                       |  1.00 |
| 59 | Observe a summary with 8 labels using MetricFamily labels method                 |  2.00 |
| 60 | Observe a summary with 16 labels using direct object access                      |  1.00 |
| 61 | Observe a summary with 16 labels using MetricFamily labels method                |  2.00 |
| 62 | Observe histogram with 0 labels with 1 buckets using direct object access        |  1.00 |
| 63 | Observe histogram with 0 labels with 1 buckets using MetricFamily labels method  |  2.00 |
| 64 | Observe histogram with 0 labels with 2 buckets using direct object access        |  1.00 |
| 65 | Observe histogram with 0 labels with 2 buckets using MetricFamily labels method  |  2.00 |
| 66 | Observe histogram with 0 labels with 4 buckets using direct object access        |  1.00 |
| 67 | Observe histogram with 0 labels with 4 buckets using MetricFamily labels method  |  2.00 |
| 68 | Observe histogram with 0 labels with 8 buckets using direct object access        |  1.00 |
| 69 | Observe histogram with 0 labels with 8 buckets using MetricFamily labels method  |  2.00 |
| 70 | Observe histogram with 0 labels with 16 buckets using direct object access       |  2.00 |
| 71 | Observe histogram with 0 labels with 16 buckets using MetricFamily labels method |  3.00 |
| 72 | Observe histogram with 0 labels with 32 buckets using direct object access       |  3.00 |
| 73 | Observe histogram with 0 labels with 32 buckets using MetricFamily labels method |  3.00 |
| 74 | Set to current time on a gauge with 0 labels using direct object access          |  0.80 |
| 75 | Set to current time on a gauge with 0 labels using MetricFamily labels method    |  1.45 |
| 76 | Set to current time on a gauge with 1 labels using direct object access          |  0.85 |
| 77 | Set to current time on a gauge with 1 labels using MetricFamily labels method    |  1.60 |
| 78 | Set to current time on a gauge with 4 labels using direct object access          |  0.81 |
| 79 | Set to current time on a gauge with 4 labels using MetricFamily labels method    |  1.72 |
| 80 | Set to current time on a gauge with 8 labels using direct object access          |  0.77 |
| 81 | Set to current time on a gauge with 8 labels using MetricFamily labels method    |  1.83 |
| 82 | Set to current time on a gauge with 16 labels using direct object access         |  0.82 |
| 83 | Set to current time on a gauge with 16 labels using MetricFamily labels method   |  2.13 |
| 84 | Set value on a gauge with 0 labels using direct object access                    |  0.00 |
| 85 | Set value on a gauge with 0 labels using MetricFamily labels method              |  1.00 |
| 86 | Set value on a gauge with 1 labels using direct object access                    |  0.00 |
| 87 | Set value on a gauge with 1 labels using MetricFamily labels method              |  1.00 |
| 88 | Set value on a gauge with 4 labels using direct object access                    |  0.00 |
| 89 | Set value on a gauge with 4 labels using MetricFamily labels method              |  1.00 |
| 90 | Set value on a gauge with 8 labels using direct object access                    |  0.00 |
| 91 | Set value on a gauge with 8 labels using MetricFamily labels method              |  1.00 |
| 92 | Set value on a gauge with 16 labels using direct object access                   |  0.00 |
| 93 | Set value on a gauge with 16 labels using MetricFamily labels method             |  2.00 |
+----+----------------------------------------------------------------------------------+-------+
```
</details>

<details>
  <summary>Metrics Collection Benchmarks, Single Threaded</summary>

```
1: 8.6.9 /usr/bin/tclsh8.6

+----+------------------------------------------------------------------------------------+----------+
|    | INTERP                                                                             |        1 |
+----+------------------------------------------------------------------------------------+----------+
|  1 | Collect 1 counter metric samples in single threaded mode                           |    11.12 |
|  2 | Collect 1 histogram metric samples with default buckets in single threaded mode    |    41.77 |
|  3 | Collect 2 counter metric samples in single threaded mode                           |    19.74 |
|  4 | Collect 2 histogram metric samples with default buckets in single threaded mode    |   103.38 |
|  5 | Collect 4 counter metric samples in single threaded mode                           |    37.89 |
|  6 | Collect 4 histogram metric samples with default buckets in single threaded mode    |   160.43 |
|  7 | Collect 8 counter metric samples in single threaded mode                           |    74.72 |
|  8 | Collect 8 histogram metric samples with default buckets in single threaded mode    |   337.34 |
|  9 | Collect 16 counter metric samples in single threaded mode                          |   138.12 |
| 10 | Collect 16 histogram metric samples with default buckets in single threaded mode   |   605.64 |
| 11 | Collect 32 counter metric samples in single threaded mode                          |   289.11 |
| 12 | Collect 32 histogram metric samples with default buckets in single threaded mode   |  1251.79 |
| 13 | Collect 64 counter metric samples in single threaded mode                          |   723.21 |
| 14 | Collect 64 histogram metric samples with default buckets in single threaded mode   |  2545.03 |
| 15 | Collect 128 counter metric samples in single threaded mode                         |  1469.24 |
| 16 | Collect 128 histogram metric samples with default buckets in single threaded mode  |  5394.35 |
| 17 | Collect 256 counter metric samples in single threaded mode                         |  4164.98 |
| 18 | Collect 256 histogram metric samples with default buckets in single threaded mode  | 12161.82 |
| 19 | Collect 512 counter metric samples in single threaded mode                         | 12823.19 |
| 20 | Collect 512 histogram metric samples with default buckets in single threaded mode  | 29541.20 |
| 21 | Collect 1024 counter metric samples in single threaded mode                        | 45075.41 |
| 22 | Collect 1024 histogram metric samples with default buckets in single threaded mode | 79777.37 |
+----+------------------------------------------------------------------------------------+----------+
```
</details>

<details>
  <summary>Metrics Collection Benchmarks, Multi-Threaded</summary>

```
 1: 8.6.9 /usr/bin/tclsh8.6

+----+--------------------------------------------------------------------------------------------------------+-----------+
|    | INTERP                                                                                                 |         1 |
+----+--------------------------------------------------------------------------------------------------------+-----------+
|  1 | Collect 1 counter samples in a multi-threaded context (1 sample / thread)                              |     41.00 |
|  2 | Collect 1 histogram samples with default buckets in a multi-threaded context (1 histogram / thread)    |     90.00 |
|  3 | Collect 2 counter samples in a multi-threaded context (1 sample / thread)                              |     53.00 |
|  4 | Collect 2 histogram samples with default buckets in a multi-threaded context (1 histogram / thread)    |    103.00 |
|  5 | Collect 4 counter samples in a multi-threaded context (1 sample / thread)                              |     83.00 |
|  6 | Collect 4 histogram samples with default buckets in a multi-threaded context (1 histogram / thread)    |    171.00 |
|  7 | Collect 8 counter samples in a multi-threaded context (1 sample / thread)                              |    164.00 |
|  8 | Collect 8 histogram samples with default buckets in a multi-threaded context (1 histogram / thread)    |    244.00 |
|  9 | Collect 16 counter samples in a multi-threaded context (1 sample / thread)                             |    311.00 |
| 10 | Collect 16 histogram samples with default buckets in a multi-threaded context (1 histogram / thread)   |    477.00 |
| 11 | Collect 32 counter samples in a multi-threaded context (1 sample / thread)                             |    738.00 |
| 12 | Collect 32 histogram samples with default buckets in a multi-threaded context (1 histogram / thread)   |   1135.00 |
| 13 | Collect 64 counter samples in a multi-threaded context (1 sample / thread)                             |   2270.00 |
| 14 | Collect 64 histogram samples with default buckets in a multi-threaded context (1 histogram / thread)   |   2670.00 |
| 15 | Collect 128 counter samples in a multi-threaded context (1 sample / thread)                            |   6081.00 |
| 16 | Collect 128 histogram samples with default buckets in a multi-threaded context (1 histogram / thread)  |   7107.00 |
| 17 | Collect 256 counter samples in a multi-threaded context (1 sample / thread)                            |  19502.00 |
| 18 | Collect 256 histogram samples with default buckets in a multi-threaded context (1 histogram / thread)  |  21515.00 |
| 19 | Collect 512 counter samples in a multi-threaded context (1 sample / thread)                            |  81516.00 |
| 20 | Collect 512 histogram samples with default buckets in a multi-threaded context (1 histogram / thread)  |  79823.00 |
| 21 | Collect 1024 counter samples in a multi-threaded context (1 sample / thread)                           | 298319.00 |
| 22 | Collect 1024 histogram samples with default buckets in a multi-threaded context (1 histogram / thread) | 338262.00 |
+----+--------------------------------------------------------------------------------------------------------+-----------+
```
</details>
