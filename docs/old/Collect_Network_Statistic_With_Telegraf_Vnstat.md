# Collect Network Statistic With Telegraf & VNSTAT

!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!

I use Telegraf on various hosts without any problem, but in some cases I'm facing issues using sysstat plugin on Orange PI zeros.

One of the most important thing for me to collect network bandwidth statistic. For this sysstat plugin is perfect, but how to achieve this without it?

I was thinking a bit, and found out that with exec plugin and vnstat I can gather information about bandwidth.

Here is the configuration:
```plain
[[inputs.exec]]
  commands = [
    "/usr/bin/vnstat -i eth0 -tr --short --json",
    "/usr/bin/vnstat -i tun0 -tr --short --json"
    ]
  timeout = "10s"
  name_suffix = "_vnstat"
  data_format = "json"
  json_name_key="vnstat"
  tag_keys= ["interface"]

```

**References:**

* [Input Data Formats](https://github.com/influxdata/telegraf/blob/master/docs/DATA_FORMATS_INPUT.md)
* [JSON](https://github.com/influxdata/telegraf/tree/master/plugins/parsers/json)

## Example InfluxDB Commands

* **List avaiable hosts:**
```sql
SHOW TAG VALUES  ON telegraf from "system" WITH KEY = "host"
```

* **Show MEASUREMENTS**
```sql
SHOW MEASUREMENTS  WITH MEASUREMENT =~ /exec.*/
```
Output:
```plain
name: measurements
name
----
exec_vnstat
```

* **List Series:**
```sql
SHOW SERIES ON telegraf FROM exec_vnstat;
```
Output:
```plain
key
---
exec_vnstat,dc=barber,host=*****-opi0,interface=eth0,rack=opi0
exec_vnstat,dc=barber,host=*****-opi0,interface=tun0,rack=opi0
```














