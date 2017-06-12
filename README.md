RSSAC002-data
=============

Metrics
-------

This repository contains YAML files published by root server operators
according to [RSSAC002](https://www.icann.org/en/system/files/files/rssac-002-measurements-root-06jun16-en.pdf) -- "Measurements of the Root Sever System".
That document describes a number of different metrics that each root
server operator should publish:

  * load-time
  * zone-size
  * traffic-volume
  * traffic-sizes
  * rcode-volume
  * unique-sources

The measurements are published daily using YAML as the file format.
The RSSAC002 document describes the YAML structure for each metric.


Filesystem Structure
--------------------

The data in this repository follows the file naming conventions in RSSAC002.  Namely:

    YYYY/MM/metric/X-root-YYYYMMDD-metric.yaml

where:

  * YYYY is the year
  * MM is the month
  * DD is the day
  * X is the root server letter
  * metric is the metric name

RSSAC002 Versions
-----------------

Three versions of the RSSAC002 specification have been published to date.
The YAML file format did not change between versions 1 and 2.  For version
3, however, the YAML file format has changed for some metrics.  For this
reason, YAML files published according to the version 3 specification
now include the following key/value pair:

    version: rssac002v3

Any YAML file without a `version` should be interpreted according to [RSSAC002v2](https://www.icann.org/en/system/files/files/rssac-002-measurements-root-07jan16-en.pdf).


Known Quirks
------------

This section describes some quriks that you might encounter while trying
to parse the YAML files in this repository.

 1. As of RSSAC002v3, only the Root Zone Maintainer is expected to publish the zone-size-metric.  With this change the `service` name has changed to `root-servers.net` and these files are published on the web sites for A-root and J-root beginning mid May 2017.

 2. Some B-root files (2016-01 to 2016-02) are published with `service: b.root-servers.org` rather than `service: b.root-servers.net`

 3. Some 'rcode-volume' YAML files were published with a valid but incorrect YAML format.  Incorrect example:

```
---
service: c.root-servers.net
start-period: '2015-01-06T00:00:00Z'
end-period: '2015-01-06T23:59:59Z'
metric: rcode-volume
rcodes:
  0: 923058858
  1: 1150521
  3: 1758242365
  4: 901
  5: 21361
  9: 23
  16: 8
```

Correct example:

```
---
version: rssac002v3
service: c.root-servers.net
start-period: '2017-04-27T00:00:00Z'
metric: rcode-volume
rcodes:
0: 1854045149
1: 1279163
2: 7
3: 3325072566
4: 305
5: 36939
9: 179
16: 36

```

 4. Some 'rcode-volume' metrics were published including RCODE values that don't make sense (out of range).  The likely explanation is that these were from responses sent *to* the server, rather than *by* the server.

