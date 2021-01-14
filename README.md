# Tcl Prometheus Package

The code in this directory provides the `prometheus-tcl` package: a pure Tcl library for instrumenting Tcl scripts with [Prometheus metrics](https://prometheus.io/docs/concepts/metric_types/).

# Getting Started

After running the provided `install` make target, import the `prometheus-tcl` package like usual

```
package require prometheus-tcl
```

This provides a number of procs in the `::prom` namespace (abbreviated for ease of typing).

## Dependencies

`prometheus-tcl` is written for Tcl 8.6 and requires a minimal set of dependencies:

- `cmdline` (argument parsing)
- `TclOO` (organizes the code providing the client API)
- `Thread` (thread safe metric operations)
- `zlib` (compressing HTTP replies)
- `tls` (only required if exposing metrics over HTTPS, either push or pull)
- `http` (only required if pushing metrics)
- `base64` (only required if pushing metrics)
- `uri` (only required if pushing metrics)

And, for the unit tests:

- `struct::list`
- `math`

## Creating Metrics

Before using a metric, declare it with one of the **`new`** procs:

```
# Create a Counter named messages_processed_total without any labels
prom::counter::new messages_processed_total -help "Number of input messages processed"

# Create a Counter named http_requests_total with some labels
prom::counter::new http_requests_total -help "HTTP requests by method and code" -labels {method code}

# Create a Gauge named rate_limit_queue_size
prom::gauge::new rate_limit_queue_size -help "Number of enqueued messages waiting to be processed"

# Create a Histogram with a method label
prom::histogram::new http_request_duration_seconds -labels {method} -buckets {0.05 0.1 0.2 0.5 1}

# Create an Info metric to track build info
prom::info::new application_build -help "Build info for application" -labels {branch version} 

# Create a Summary for request duration
prom::summary::new microservice_rpc_duration_seconds -help "Microservice RPC duration in seconds"
```

When defining a metric with labels, only the label keys should be provided.

Calling **`new`** more than once for the same metric name throws an error (unless a suitable [policy](#name-conflict-policy) has been set to override that behavior).

Likewise, trying to use a metric without a prior call to **`new`** throws an error (unless a suitable [policy](#name-missing-policy) has been set to override that behavior).

Also, providing an [invalid metric name or label key](https://prometheus.io/docs/concepts/data_model/) throws an error.

If no errors occur, the **`new`** procs return the empty string.

After declaring a metric, manipulate its value by passing its name to one of [the procs detailed in a later section](#using-created-metrics).

### Provided **`new`** Procs

**prom::counter::new** *metricName* ?-**help** *helpText*? ?-**namespace** *metricNamePrefix*? ?-**labels** *labelKeys*? ?-**timestamp**?

**prom::gauge::new** *metricName* ?-**help** *helpText*? ?-**namespace** *metricNamePrefix*? ?-**labels** *labelKeys*? ?-**timestamp**? ?-**mergePolicy** *policy*?

**prom::histogram::new** *metricName* ?-**help** *helpText*? ?-**namespace** *metricNamePrefix*? ?-**labels** *labelKeys*? ?-**timestamp**? ?-**buckets** *bucketBoundaries*

**prom::info::new** *metricName* ?-**help** *helpText*? ?-**namespace** *metricNamePrefix*? ?-**labels** *labelKeys*? ?-**timestamp**?

**prom::summary::new** *metricName* ?-**help** *helpText*? ?-**namespace** *metricNamePrefix*? ?-**labels** *labelKeys*? ?-**timestamp**?


#### Common Arguments

Given a [valid metric name](https://prometheus.io/docs/concepts/data_model/), *metricName*, **`new`** creates a [Counter](https://www.robustperception.io/how-does-a-prometheus-counter-work), [Gauge](https://www.robustperception.io/how-does-a-prometheus-gauge-work), [Histogram](https://www.robustperception.io/how-does-a-prometheus-histogram-work), [Info](https://www.robustperception.io/how-to-have-labels-for-machine-roles) or [Summary](https://www.robustperception.io/how-does-a-prometheus-summary-work) metric.

To set the [HELP description](https://prometheus.io/docs/instrumenting/exposition_formats/#comments-help-text-and-type-information) for the metric, provide the optional -**help** argument.  If no -**help** is provided, the *metricName* will be used.  The [Prometheus documentation](https://prometheus.io/docs/instrumenting/writing_clientlibs/#metric-description-and-help) is fairly strict about requiring help text, but `prometheus-tcl` is not.  Help text is recommended but not required.  

For specifying the metric's labels, provide a list of label keys, *labelKeys*, to the -**label** argument.  The order of elements in *labelKeys* is important: label values will need to be passed in that same order when calling the procs [detailed below](#using-created-metrics) for using the metrics, e.g., incrementing it or observing a value.  

Optionally the -**namespace** argument can contain a string *metricNamePrefix* that will be prepended (along with an underscore) to the *metricName* passed to a **`new`** proc.  Although a -**namespace** can be provided to **`new`**, the preferred way is to [set a default global namespace value](#namespaces) for metrics created with **`new`**.

Lastly, if -**timestamp** is provided, then each modification to the metric will also be accompanied by an epoch timestamp in milliseconds.  This timestamp will show up in the data provided at scrape time, e.g., by calling `prom::collect`.

#### Gauge Specific

If using `prometheus-tcl` in a multi-threaded application, it is possible to merge the metrics across some subset of Tcl threads.  In that case, [merging metrics](#merge-policy) is fairly straightforward, except for gauges where it is not always clear what the best option is.  For that situation, the -**metricPolicy** option exists.  For *policy* it accepts `max` (the default), `min` or `sum`.

#### Histogram Specific

The default buckets for a histogram are `{.005 .01 .025 .05 .1 .25 .5 1 2.5 5 10}`.  These are taken from the [golang client](https://github.com/prometheus/client_golang/blob/master/prometheus/histogram.go#L57-L67).  See the link for further explanation. 

To override the defaults, provide a list of numbers, *bucketBoundaries*, sorted in increasing order to the -**buckets** argument.

*bucketBoundaries* must contain at least one value excluding `Inf`.

The `Inf` bucket does not need to be explicitly provided.

##### Bucket Boundary Creation

Two helper procs ease common-case bucket creation.  

Both helper procs return a list of bucket boundaries.

###### Linear Buckets

For consecutive bucket boundaries separated by a common difference

**prom::linear_buckets** *start* *width* *count*

*count* must be greater than or equal to 1

###### Exponential Buckets

For consecutive bucket boundaries separated by a common factor

**prom::exponential_buckets** *start* *factor* *count*

*start* must be greater than 0

*count* must be greater than or equal to 1

*factor* must be greater than 1

###### Example Usage

```
# Example of linear buckets
prom::linear_buckets 0 5 10

# Returns the following list
0 5 10 15 20 25 30 35 40 45

# Example of exponential buckets
prom::exponential_buckets 1 2 5

# Returns the following list
1 2 4 8 16
```

#### Info Specific

Info metrics are not part of the Prometheus standard.  Behind the scenes, they are actually Gauges with a value of `1.0.`.  

However, it is common practice to use this style of metric for exposing information like [https://www.robustperception.io/exposing-the-software-version-to-prometheus](software versions) or [machine roles](http://www.robustperception.io/how-to-have-labels-for-machine-roles/).  

The **prom::info::new** proc takes the same arguments as the others (except for Histograms), but adds two wrinkles:

- At least one label is required.  An error will be thrown if the -**labels** option value is an empty list.
- If the *metricName* does not end with `_info`, `prometheus-tcl` will automatically append `_info` to it.  There is no way to disable this, so use a Gauge explicitly if this is not desired.

#### Summary Specific

Note that summary metric types in `prometheus-tcl` do **NOT** calculate Phi-quantiles.  Instead, they only provide the two Counters, `_sum` and `_count`.  As stated in the link above:

> Overall summarys without quantiles are a nice cheap way to track latencies, amount of data transferred per request, records accessed etc. as it only uses two time series per labelset. 


### Namespaces

When declaring new metrics, a global namespace, which acts as a metric name prefix, can be set using the **`prom::set_namespace`** proc, which takes a single argument, *namepsace*.  By default the namespace is the empty string, but, if not, the value of *namespace* and an underscore will be prefixed to every metric name provided to a `new` proc.  

When a non-empty namespace has been set, the full name of the metric is exposed when `prom::collect` is called.  Outside of that, though, the *namespace* value should not be provided in any `prometheus-tcl` proc calls requiring a metric name.

```
# Before declaring metrics, set the namespace
prom::set_namespace flightaware

# Create a metric whose full name will be flightaware_departures_total, but only as seen by Prometheus
prom::counter::new departures_total -help "Count total departures issued by FlightAware" -labels {airline adhoc}

# Use the metric without needing to mention the namespace
prom::counter::inc departures_total $airline $adhoc 

# Providing the full name of the counter throws an error 
prom::counter::inc flightaware_departures_total $airline $adhoc

# What is displayed during a scrape by Prometheus:

# HELP departures_total Count total departures issued by FlightAware
# TYPE departures_total counter
departures_total{airline="1",adhoc="1"} 1.0
```

### Metric Name Callback

When defining and using metrics, following [the Prometheus naming best practices](https://prometheus.io/docs/practices/naming/) can lead to fairly verbose metric names.  Typing the full metric name can become tedious, and when used with labels, can lead to very long line lengths.  To help address this problem somewhat, `prometheus-tcl` allows for setting a callback for controlling metric names that will be invoked at metric creation time, i.e., when calling a **`new`** proc:

**prom::metic_name_callback** *callback*

Set the callback by passing a non-empty string to *callback*. 

Unset any previously set callback by passing in `""` as *callback*.

The callback will be passed two arguments, *metricType* and *metricName*.  

The callback must return a string representing the full metric name to use (excluding any namespace).

When a metric name callback has been set and a metric has been declared, use the same value passed to **`new`** when interacting with the metric.

For example, to automatically append `_total` to any counter metrics:

```
proc counter_naming {metricType metricName} {
	if {$metricType eq "counter"} {
		set metricName ${metricName}_total
	}

	return $metricName
}

prom::metric_name_callback counter_naming

# When exposed to Prometheus, the name will be example_total
prom::counter::new example

# When using the counter, pass the same name provided to new
prom::counter::inc example

# Do not use the name returned by the metric name callback
# It will traceback
prom::counter::inc example_total; # error
```

### Name Conflict Policy

While the default behavior of **`new`** is to throw an error if the metric name being declared already exists.  This can be modified by setting the name conflict policy to `ignore`

**prom::set_name_conflict_policy** *policyName*

It supports a *policyName* of  `error` policy (the default) or `ignore` which silently returns without doing anything.

### Collection Registry

By default `prometheus-tcl` registers every metric created with **`new`** into a default registry created at package load (a registry is a `prom::Registry` object).  This should cover the majority of cases.  

For more advanced scenarios where an alternate registry is needed use

**prom::set_collection_registry** *registryObject*

After setting the collection registry, all subsequent calls to `prom::collect` will use the provided *registryObject*.

## Using Created Metrics

Once a metric has been declared with **`new`**, use its name to access the expected Prometheus operations.

Label values are provided after the metric name and the operation's exepected argument(s).  

Label values must be provided in the same order that their corresponding label keys were provided to the **`new`** command.

### Counter

**prom::counter::inc** *metricName* ?-**amount** *amount*? ?*labelValue ...*?

Increment *metricName* either by 1 (the default) or by some other non-negative *amount* provided to the -**amount** argument.  *amount* can be any value recognized by `string is double -strict`.

### Gauge

**prom::gauge::inc** *metricName* ?-**amount** *amount*? ?*labelValue ...*?

Increment *metricName* either by 1 (the default) or by some other non-negative *amount* using the -**amount** option.  *amount* can be any value recognized by `string is double -strict`.

**prom::gauge::dec** *metricName* ?-**amount** *amount*? ?*labelValue ...*?

Decrement *metricName* either by 1 (the default) or by a non-negative *amount* using the -**amount** option.  *amount* can be any value recognized by `string is double -strict`.

**prom::gauge::set_value** *metricName* *value* ?*labelValue ...*? 

Set *metricName* to a particular numeric *value*.  *value* can be anything recognized by `string is double -strict`.

**prom::gauge::set_to_current_time** *metricName* ?*labelValue ...*? 

Set *metricName* to the current epoch timestamp in seconds.

**prom::gauge::time** *metricName* *script* ?*labelValue ...*? 

Run *script* using [Tcl's time command](https://www.tcl.tk/man/tcl8.6/TclCmd/time.htm), convert the result to seconds and set that value in the gauge named *metricName*.

### Histogram

**prom::histogram::observe** *metricName* *value* ?*labelValue ...*? 

Observe a *value* for the Histogram named *metricName*.

**prom::histogram::time** *metricName* *script* ?*labelValue ...*? 

Run *script* using [Tcl's time command](https://www.tcl.tk/man/tcl8.6/TclCmd/time.htm), convert the result to seconds and observe that value in the histogram named *metricName*.

### Summary

**prom::summary::observe** *metricName* *value* ?*labelValue ...*? 

Observe a *value* for the Summary named *metricName*.

**prom::summary::time** *metricName* *script* ?*labelValue ...*? 

Run *script* using [Tcl's time command](https://www.tcl.tk/man/tcl8.6/TclCmd/time.htm), convert the result to seconds and observe that value in the summary named *metricName*.

### Info

**prom::info::labels** *metricName* *labelValue* ?*labelValue ...*?

Set the label values for the Info metric *metricName*.

Since labels are required for creating Info metrics, at least one *labelValue* value must be provided.

### Note About *`labelValue`* Arguments

For any proc detailed in [the section above](#using-created-metrics), when providing the label values for a given metric name, the values **MUST** be in the order provided to the -**labels** argument to **`new`**.

For example, assume we declare a Counter named `total` with three label keys, `k1`, `k2`, and `k3`, represented by the Tcl list `{k1 k2 k3}`:

```
prom::counter::new total -help "Example of the importance of labelValue order" -labels {k1 k2 k3}
```

With `total` declared, assume we now want to increment `total` with label values `k2="v2"`, `k3="v3"`, and `k1="v1"`.  Since we declared `total` with the *labelKeys* list `{k1 k2 k3}`, we need to provide label values in that order:

```
prom::counter::inc total v1 v2 v3
```

### Note About Timing

The **`time`** procs provided by **prom::gauge**, **prom::histogram** and **prom::summary** only support timing in seconds.  

Restricting the units to seconds conforms with [Prometheus client guidelines](https://prometheus.io/docs/instrumenting/writing_clientlibs/) and the [metric naming best practices](https://prometheus.io/docs/practices/naming/).

**`time`** only provides the wall time it took to execute the *script* argument.  If you need CPU time, see [`times` from the TclX extension](https://github.com/flightaware/tclx).

Importantly, these procs do **NOT** catch exceptions; however, if an error is thrown while evaluating *script*, *metricName* will still be updated with *script*'s execution time.

### Name Missing Policy

By default it is an error to use one of the procs in this section without a prior call to **`new`**.  

`prometheus-tcl` can also silently ignore any attempt to manipulate an undeclared metric name by setting the missing name policy

**prom::set_name_missing_policy** *policy*

To ignore any attempt to use an undeclared metric name, pass a value of `ignore` as the *policy* argument.

## Collecting Metrics

### Metrics As a String

For getting the metrics in Prometheus' text-based [exposition format](https://prometheus.io/docs/instrumenting/exposition_formats/) use

**prom::collect**

which takes no arguments and returns a Prometheus formatted string of the current metrics created using `prometheus-tcl`.

`prometheus-tcl` only supports the Prometheus text format.

### Metrics Over HTTP

To expose a HTTP port for Prometheus to scrape use 

**prom::expose** ?-**address** *address*? ?-**port** *port*? ?-**tls**? ?-**tlsArgs** *args*? ?-**path** *path*?

Requires entering the event loop. 

By default `prometheus-tcl` listens on the wildcard address on *port* `1347` for *path* `/metrics` where *path* is the [`request-target` of RFC7230](https://tools.ietf.org/html/rfc7230#section-3.1.1).

The -**address** option supports the same values that the Tcl `socket` command does for its `-myaddr` option.

TLS support can be enabled with the boolean -**tls** argument.  To configure TLS, pass a single list of arguments to the -**tlsArgs** option.  It takes all arguments accepted by `tcltls`' [`tls::import` command](https://core.tcl-lang.org/tcltls/wiki?name=Documentation#tls::import).

Importantly, if you use TLS with **prom::expose** and a request fails, e.g., a client does not even use TLS for a request, the [background exception handler](https://www.tcl-lang.org/man/tcl8.6/TclCmd/interp.htm#M10) is called, so be sure to set one when using this option.  The *message* argument passed to the background error handler for these protocol failures starts with the string `SSL channel`.

*path* can be any glob pattern.  If a request is made to a URI that doesn't match *path*, a `400 Bad Request` is sent.

### Metrics To A File

**prom::collect_to_file** *filePath* 

writes the results of `prom::collect` to a file in a non-blocking way.  It returns `0` if an error occurred or `1` if the file was written successfully. 

This can be used, for instance, with the [`node_exporter`'s Textfile Collector](https://github.com/prometheus/node_exporter#textfile-collector).

### PushGateway

For pushing metrics to [a PushGateway](https://github.com/prometheus/pushgateway) the following procs are provided:

**prom::push_to_gateway** *gateway* *job* ?-**groupingKey** *labelsDict*? ?-**timeout** *timeoutMS*?

**prom::pushadd_to_gateway** *gateway* *job* ?-**groupingKey** *labelsDict*? ?-**timeout** *timeoutMS*?

**prom::delete_from_gateway** *gateway* *job* ?-**groupingKey** *labelsDict*? ?-**timeout** *timeoutMS*?

Given a *gateway* hostname, *job* value and an optional [`dict`](https://www.tcl.tk/man/tcl8.6/TclCmd/dict.htm) of labels, *labelsDict*, send an HTTP(s) `PUT` (**prom::push_to_gateway**), `POST` (**prom::pushadd_to_gateway**) or `DELETE` (**prom::delete_from_gateway**) to the PushGateway.

The *gateway* hostname should be the PushGateway's domain name or IP address.  It can optionally include a URI scheme of `http` or `https` (`http` is assumed if none is specified) along with a `:` and port number (`9091` is assumed as the port if none is specified).  

On success, which means the PushGateway provided a status code indicating such, the **`prom::*_gateway`** procs return `1` or `0` otherwise.  

These procs will throw an error if the *gateway* is not provided in an acceptable format. 

#### Gateway Hostnames

To make clear the accepted *gateway* values in the above procs, consider an imagined host `gateway.com` running a PushGateway on port `12345`:

```
# Since no scheme provided, http used by default
# If no port is provided, 9091 is assumed by default
gateway.com:12345

# Alternate way of writing the above
http://gateway.com:12345

# For TLS, must explicitly specify https 
https://gateway.com:12345
```

If an `https` scheme is provided, `tcltls` is used to encrypt the connection to the gateway.

## Multi-threaded Setting

### Collection Policy

`prometheus-tcl` supports a multi-threaded mode of operation.  This is off by default but can be enabled by setting a multi-threaded collection policy of `mt` using the proc

**prom::set_collection_policy** *policy*

By default the *policy* is `st`, or single-threaded.  That means that `prom::collect` only collects metrics from the current Tcl interpreter.  

If a *policy* of `mt` is specified, then `prom::collect` will aggregate metrics from [all threads specified for collection](#collect-from-some-but-not-all-threads) and merge their values (for any given metric name and labels).

The `mt` policy assumes a Tcl program using [threads](https://www.tcl.tk/man/tcl/ThreadCmd/thread.htm) in the context of [the Tcl threading model](https://www.tcl.tk/doc/howto/thread_model.html).  In a multi-threaded application, it is possible that each thread could expose its metrics on a separate port.  However, this has several drawbacks, one of which could be the creation of too many values for the Prometheus-added `instance` label.  It is also likely that each thread will share some (if not all) of the same metric names.  In that case, it is desirable for `prom::expose` to return merged metrics across [all threads with metrics to share](#collect-from-some-but-not-all-threads).  That is the multi-threaded collection policy supported by `prometheus-tcl`. 

Note that in the multi-threaded context, `prometheus-tcl` does not have safeguards against multiple threads using the same metric name but different label keys.  If that occurs, the behavior is undefined.  It is up to application developers to enforce this, preferably by doing metric creation in a proc shared by all threads to enforce uniformity.

### Aside On Other Architectures

In passing it is worth mentioning that it would be possible to avoid merging metrics by creating, for instance, a [cpptcl](https://github.com/flightaware/cpptcl) extension or [tsv](https://www.tcl.tk/man/tcl/ThreadCmd/tsv.htm)s for metric instrumentation in a multi-threaded setting.  Either one of those could be fine solutions and were considered, but are not used in this package. 

### Multi-threaded Collection Timeout 

When collecting metrics in a multi-threaded setting it is possible that one of the threads could block indefinitely and stall the thread that called `prom::collect`.  To avoid this situation, `prometheus-tcl` uses `thread::send -async` along with an after event timeout and `vwait` to set an upper bound on how long collection can take before giving up.  

By default a collection timeout of `10` milliseconds is used, but, depending on workload and number of threads, this could use adjustment.  To set a different value in milliseconds use

**prom::set_mt_collection_timeout** *timeoutMS*

To see the current collection timeout value

**prom::get_mt_collection_timeout**

The timeout value is for the time taken to collect from all threads specified for collection not for an individual thread.

If some threads fail to return a value before the timeout no error will result.  Any collected metrics will be exposed.

### Collect From Some But Not All Threads

By default, `prometheus-tcl`'s multi-threaded collection policy collects from all threads returned by `thread::names`.  To set only some threads for collection use

**prom::set_mt_collection_threads** *threadIDs*

### Merge Policy

When merging metrics the following rules are followed:

- Metrics with the same name and labels (includes keys and values) can be merged
- If threads provide different label keys for the same metric name, the result is undefined
- Counters have their values added together 
- Gauges by default take the maximum value seen.  However, this can be modified with the -**mergePolicy** option for `prom::gauge::new`.  Supported merge policies are `max`, `min`, and `sum`
- Histograms have the count for each bucket and the overall count and total summed 
- Summaries have their count and total values summed
- For metrics with timestamps (this is controlled at metric creation time), typically the maximum timestamp seen is taken.  This is not the case, however, for gauges where it depends on the merge policy.  A `sum` policy uses the maximum timestamp seen but `max` or `min` use the timestamp of the maximum or minimum value seen

## Compliance with Prometheus [Client Guidelines](https://prometheus.io/docs/instrumenting/writing_clientlibs/)

`prometheus-tcl` complies with most if not all of the client library recommendations.

For instance:

- It is thread safe for Tcl's threading model
- It offers Counter and Gauge and both Summary and Histogram
- It has a default registry (the client API hides this detail from the user)
- Using the different classes defined in the `prom` namespace, it is possible to use a different registry
- All metrics have the mandatory methods and names (except for `prom::gauge::set_value` to avoid collision with `::set`)
- Unit tests are included (can run them with the **`test`** make target)

## Further Documentation

If you would like additional documentation on the package and have [Doxygen](http://www.doxygen.nl) installed, a `docs` Make target will run `doxygen`.  This will generate output in the `docs/` sub-directory of the current directory. 
