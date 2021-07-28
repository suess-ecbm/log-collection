# Elastic helpers and documentation

This repository contains helper scripts and conventions which have emerged at Geberit from running the Elastic stack for log management to make Elastic fit best into our environment. They might also be interesting for others so they are published here for reference, feedback and usage.

We have not fully adapted to the Elastic Common Schema yet. If you start out new, you should start with that from the beginning.

## Configuration files and scripts

* [./bin/](/bin): Helper scripts

  * `get_es_*`

    For automation and scripting, you will need a way to access certain information like the URL of a Elasticsearch node and possibly credentials. Curator had similar needs and solved it by using a configuration file. We just reuse the configuration file of Curator and make it accessible for other uses with small shell scripts that output the needed information to STDOUT.

* [./curator/](/curator): Curator examples
* [./index_template_backup/](/index_template_backup): Index template backup Makefile script for easy (version controlled) backup and restore of index templates.

## Elasticsearch

### Shard size

Search for shards that are outside of the recommended size (big but no bigger than 50 GB):

```
GET /_cat/shards?bytes=gb&s=store:desc,p,s,node&v&h=i,store,p,s,node
```

## Kibana

### Saved Searches

Field order: @timestamp, severity, host, [custom fields of that index-set]

### Settings

```JSON
{
  "config": {
    "context:defaultSize": "3",
    "dateFormat:dow": "Monday",
    "dateFormat": "ddd YYYY-MM-DD HH:mm:ss.SSS",
    "format:bytes:defaultPattern": "0.[0] b",
    "format:number:defaultPattern": "0.[000]",
    "dateFormat:scaled": """
[
  ["", "HH:mm:ss.SSS"],
  ["PT1S", "HH:mm:ss"],
  ["PT1M", "HH:mm"],
  ["PT1H", "ddd YYYY-MM-DD HH:mm"],
  ["P1DT", "ddd YYYY-MM-DD"],
  ["P1YT", "YYYY"]
]
""",
    "savedObjects:perPage": "5",
    "context:tieBreakerFields": [
      "count",
      "_doc"
    ]
  }
}
```

The date format includes the weekday to allow for easier correlation. For example log volume often depends on the weekday. The format is based on the time and date specification from systemd (ref: https://manpages.debian.org/stretch/systemd/systemd.time.7.en.html).

### Color highlighting for fields in index-pattern

Kibana supports the highlighting of values by using colors. This comes in handy for fields like `severity`, `nagios_state` and more. From a UX perspective it is desirable to have standard colors or colors which we are already used to.

#### Color of the nagios_state field

Colors have been copied from Icinga classic via the web developer tools.

The following Update By Query API call can be used to add this color highlighting to all Kibana index patterns where the field `nagios_state` exists and which currently does not have any field formatting configured.

```
## ES 6.X:
POST .kibana-6/doc/index-pattern:icinga-alerts-*/_update
{
  "script": {
    "source": "ctx._source['index-pattern']['fieldFormatMap'] = params.fieldFormatMap;",
    "lang": "painless",
    "params": {
      "fieldFormatMap" : """{"nagios_state":{"id":"color","params":{"fieldType":"string","colors":[{"range":"-Infinity:Infinity","regex":"^(?:OK|UP)$","text":"#000000","background":"#00CC33"},{"range":"-Infinity:Infinity","regex":"^(?:WARNING)$","text":"#000000","background":"#FFA500"},{"range":"-Infinity:Infinity","regex":"^(?:CRITICAL|DOWN)$","text":"#000000","background":"#FF3300"},{"range":"-Infinity:Infinity","regex":"^(?:UNKNOWN|UNREACHABLE)$","text":"#000000","background":"#E066FF"},{"range":"-Infinity:Infinity","regex":"^(?:PENDING)$","text":"#000000","background":"#c0c0c0"}]}}}"""

    }
  },
  "query": {
    "query_string": {
      "query": "+index-pattern.fields:nagios_state -_exists_:index-pattern.fieldFormatMap"
    }
  }
}
```

#### Color of the severity field

Severity to color mapping was put together in the following steps:

1. Integer value → Keyword: https://en.wikipedia.org/wiki/Syslog#Severity_level
2. Meaning (Keyword from 1.) → Color name: https://www.ibm.com/support/knowledgecenter/en/SSNFET_9.2.0/com.ibm.netcool_OMNIbus.doc_7.4.0/omnibus/wip/user/concept/omn_usr_el_eventseveritylevels.html
3. Color name → Color RGB HTML code: http://clrs.cc/

Note that the severity value might not always be an integer for example when it is an average over multiple documents. For this reason, it is implemented as follows:

Range         | Severity keyword | Color name    | Color RGB HTML code
------------- | -------------    | ------------- | -------------
-∞:2.5        | Critical         | Red           | #FF4136
2.5:3.5       | Error            | Orange        | #FF851B
3.5:4.5       | Warning          | Yellow        | #FFDC00
4.5:5.5       | Notice           | Green         | #2ECC40

The following Update By Query API calls can be used to add this color highlighting to all Kibana index patterns where the field `severity` exists and which currently does not have any field formatting configured.

```
## ES 5.X:
POST .kibana/_update_by_query
{
  "script": {
    "inline": "ctx._source.fieldFormatMap = params.fieldFormatMap;",
    "lang": "painless",
    "params": {
      "fieldFormatMap" : """{"severity":{"id":"color","params":{"fieldType":"number","colors":[{"range":"-Infinity:2.5","regex":"<insert regex>","text":"#000000","background":"#FF4136"},{"range":"2.5:3.5","regex":"<insert regex>","text":"#000000","background":"#FF851B"},{"range":"3.5:4.5","regex":"<insert regex>","text":"#000000","background":"#FFDC00"},{"range":"4.5:Infinity","regex":"<insert regex>","text":"#000000","background":"#2ECC40"}]}}}"""
    }
  },
  "query": {
    "query_string": {
      "query": "+fields:severity -_exists_:fieldFormatMap"
    }
  }
}

## ES 6.X and 7.X:
POST .kibana-6/_update_by_query
// Or
POST .kibana_7/_update_by_query
{
  "script": {
    "source": "ctx._source['index-pattern']['fieldFormatMap'] = params.fieldFormatMap;",
    "lang": "painless",
    "params": {
      "fieldFormatMap" : """{"severity":{"id":"color","params":{"fieldType":"number","colors":[{"range":"-Infinity:2.5","regex":"<insert regex>","text":"#000000","background":"#FF4136"},{"range":"2.5:3.5","regex":"<insert regex>","text":"#000000","background":"#FF851B"},{"range":"3.5:4.5","regex":"<insert regex>","text":"#000000","background":"#FFDC00"},{"range":"4.5:Infinity","regex":"<insert regex>","text":"#000000","background":"#2ECC40"}]}}}"""
    }
  },
  "query": {
    "query_string": {
      "query": "+index-pattern.fields:severity -_exists_:index-pattern.fieldFormatMap"
    }
  }
}

## ES 7.12+ with ECS:
## Note that the search for index-pattern.fieldFormatMap does not work anymore because this field is not indexed anymore. The recommended way to use this is to manually check for documents without index-pattern.fieldFormatMap and update the query below.
POST .kibana/_update_by_query
{
  "script": {
    "source": "ctx._source['index-pattern']['fieldFormatMap'] = params.fieldFormatMap;",
    "lang": "painless",
    "params": {
      "fieldFormatMap" : """{"event.severity":{"id":"color","params":{"fieldType":"number","colors":[{"range":"-Infinity:2.5","regex":"<insert regex>","text":"#000000","background":"#FF4136"},{"range":"2.5:3.5","regex":"<insert regex>","text":"#000000","background":"#FF851B"},{"range":"3.5:4.5","regex":"<insert regex>","text":"#000000","background":"#FFDC00"},{"range":"4.5:Infinity","regex":"<insert regex>","text":"#000000","background":"#2ECC40"}]}},"log.level":{"id":"color","params":{"fieldType":"string","colors":[{"range":"-Infinity:Infinity","regex":"^(?:emerg|alert|crit)","text":"#000000","background":"#FF4136"},{"range":"-Infinity:Infinity","regex":"^(?:err)","text":"#000000","background":"#FF851B"},{"range":"-Infinity:Infinity","regex":"^(?:warn)","text":"#000000","background":"#FFDC00"},{"range":"-Infinity:Infinity","regex":"^(?:notice|info|debug)","text":"#000000","background":"#2ECC40"}]}},"tags":{"id":"color","params":{"fieldType":"string","colors":[{"range":"-Infinity:Infinity","regex":".*untrusted.*","text":"#000000","background":"#FF851B"},{"range":"-Infinity:Infinity","regex":"parse_failure","text":"#000000","background":"#FF4136"},{"range":"-Infinity:Infinity","regex":"parse_warning","text":"#000000","background":"#FFDC00"}]}},"host.uptime":{"id":"duration"}}"""
    }
  },
  "query": {
    "query_string": {
      "query": "+index-pattern.title:log_mypattern__v1"
    }
  }
}
```

### Human readable severity keyword using scripted field (painless)

Suggested field name: `severity_string`

```Painless
['emerg', 'alert', 'crit', 'err', 'warn', 'notice', 'info', 'debug'][(byte)doc['severity'].value];
```

### Location ID extracted from host field using scripted field (painless)

Assumption is that the host field matches the pattern `/^[a-z](?<location_id>[a-z]{4}).*$/`.

Suggested field name: `host_location`

```Painless
doc['host.keyword'].value.substring(1, 5);
```

### CMDB fields as scripted fields

It can be useful to have fields from the CMDB shown in search results. This is such a rare usecase that this data should not be indexed into Elasticsearch.

```Painless
HashMap mapping = [
'gnu': 'webserver',
'matrix': 'fileserver'
];
mapping[doc['host.keyword'].value];
```

Note that the very last key-value pair cannot be terminated by a comma.

The mapping can be generated using `jq` for example:

```Shell
jq --raw-output '.product.search_code[] | ("''" + .search_code + "'': ''" + .service + "'',")' | sed '$s/,$//'
```

Depends on Elasticsearch >= 6.6.0. Ref: https://github.com/elastic/elasticsearch/pull/35184
