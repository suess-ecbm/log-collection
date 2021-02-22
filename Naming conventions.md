# Naming conventions

## Index naming convention

How should indices be named in Elasticsearch?

* https://discuss.elastic.co/t/best-practice-index-naming/38007
* https://stackoverflow.com/questions/39907523/are-there-conventions-for-naming-organizing-elasticsearch-indexes-which-store-lo
* https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-create-index.html
* https://github.com/elastic/ecs/issues/313

Version 1 developed naturally and taught us some lessons which later guided the design of version 2.

### Version 1

Status: Used in production.

Index name components:

Separated by hyphen.

* `#source`: Example: zypper-eventlog
* Index format version: Example: v23
* Timestamp as invalid RFC 3339/ISO 8601 because it uses dots instead of hyphens. Example: 2023.05.23

Examples:

* `zypper-eventlog-v7-2018.04.04`
* `ilo-v7-2018.04`
* `.curator-v7-2018`
* `critical-logs-v7-2018`
* `e2e-checklog-v7-2018.04.04`
* `e2e-dev-checklog-v7-2018.04.04`

Issues arise when trying to define index-patterns in Kibana because of overuse of the hyphen and no clear structure.

### Version 2

Status: Approved for production.

Scope: In scope are all indices which are not system indices (of Elasticsearch, Logstash and Kibana).

Requirements:

* Support mapping changes without reindexing.
* Support efficient, heterogeneous retention time implementation with easy to spot index names for snapshot/restore operations. No index rollover is used.
* Support efficient permission model where different entities have access to different data.

The index naming syntax is defined using ABNF. Refer to https://tools.ietf.org/html/rfc5234 for details. Restrictions from https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-create-index.html were considered.

```ABNF
valid-component-char = %x61-7A / DIGIT        ; a-z or 0-9
index-type           = 1*valid-component-char
ecs-category         = 1*valid-component-char ; https://www.elastic.co/guide/en/ecs/current/ecs-allowed-values-event-category.html
index-source         = 0*1(ecs-category "-") 0*5(1*valid-component-char "-") 1*valid-component-char
index-key-value      = *(1*valid-component-char "-") 1*valid-component-char "=" *(1*valid-component-char "-") 1*valid-component-char
index-version        = 1*DIGIT
index-time-range     = date-time ; See below.
index-name           = index-type "_" index_type *("_" index-key-value) "__v" index-version "_" index-time-range
```

Details:

* `index-type`: Some top level type of the index. Loosly related to https://www.elastic.co/guide/en/ecs/current/ecs-allowed-values-event-kind.html. Examples:

    * `log` (This would include ECS `event.kind` "alert", "event", "state" and possibly others as ECS `event.kind` is still beta as of 2020-09)
    * `metric` (`perf` was proposed as alternative to `metric` but is not used because we could also have temperature sensor data in Elasticsearch which are not performance data but still some kind of measurement.)
    * `unknown`

    The `index-type` has been introduced to allow to have index templates which serve as a default for the type.

    This also addresses the issue to only match custom indices using the [`index_patterns`](https://www.elastic.co/guide/en/elasticsearch/reference/6.2/indices-templates.html) and no hidden/system indices. There is currently no way to ensure this otherwise. Ref: https://github.com/elastic/elasticsearch/issues/17247

* `index-source`: Hierarchical. The first part should not be vendor specific. Example: network-firewall-sessions.
* `index-key-value` (optional): One or more key value pairs, kv separated by colon (`=`).

    Because this component is optional, we need a way to match the end of the component. For this, one additional underscore is used as separator regardless if this component is used or not. Another project which uses such convention is DebOps (not exactly for that reason but still). Example: `_env=staging`. Because the order of components is important for matching with index patterns, new key value pairs are always appended in the assumption that this causes the least issues with existing index patterns. For keys or values consisting of multiple words hyphens are used. Underscores would result in issues with multiple key-value pairs (where does the value end and where does the key start?).

    Defaults if key not specified: env=prod

    `index-source` vs. `index-key-value`: The distinction is not always easy. `env` and `site` should be key value pairs. Application can be part of the Source/Type if it makes sense.

* `index-version`: Version number that is typically increased when breaking mapping changes are emitted by sources.

    This is done for the following reasons:

    1. To make it possible in Kibana to create new index-patterns without conflicts.
    2. To allow reindexing old indices into new once. This requires a new name.
    3. To support agents running the old version and new version in parallel.

    Note that there is one downside to this. When you refer to a document in
    another index with `{{index}}/{{_id}}`, the index will change and
    the ref will not work anymore. An alternative is to use index aliases for this.

* `index-time-range`: Timestamp in ISO 8601. RFC 3339 profile where ISO 8601 is ambiguous while still allowing less persision as in RFC 3339. All characters MUST BE lower case. No ISO 8601 time intervals are used. Instead, a timestamp where the precision defines the range.

Background on using underscore(s) as component separator:

The switch from hyphens to underscores as component separator has been done for the following reasons:

* Index names should contain a timestamp. For timestamps the universal standard is RFC 3339/ISO 8601 which uses hyphens.
* It has been used in the [Elasticsearch - The Definitive Guide](https://www.elastic.co/guide/en/elasticsearch/guide/current/time-based.html).

Examples:

* `log_network-switch__v1_2023-05`

  ```
  #source: network-switch_vendor=CumulusExpress
  ```

* `log_network-switch-management__v1_2023-05`
* `log_network-security__v1_2023-05`

   For example for NAC.

* `log_network-ap__v1_2023-05-23`
* `log_network-ap-controller__v1_2023-05`
* `log_network-wan-optimization__v1_2023-05`
* `log_network-firewall__v1_2023-05`
* `log_network-firewall-sessions__v1_2023-w23`
* `log_network-firewall-sessions_duration=longRunning__v1_2023-05-23`

* `log_network-firewall-ips__v1_2023-05-23`
  IPS specific logs only.

* `log_network-firewall-waf__v1_2023-05-23`
  WAF specific logs only.

* `log_server-bmc__v1_2023-05`
* `log_server-package-manager_env=staging__v1_2023-05-23`
* `log_server-windows_service=dc_logName=security__v1_2023-05-23`
* `log_server-windows_service=dc_logName=other__v1_2023-05`
* `log_server-windows_service=main_logName=security__v1_2023-05-23`
* `log_server-windows_service=main_logName=other__v1_2023-05`
* `log_server-gnu-linux__v1_2023-05`
* `log_server-windows-dhcp__v1_2023-05` (theoretical)
* `log_server-windows-dns__v1_2023-05` (theoretical)
* `log_server-windows-file-server__v1_2023-05` (theoretical)
* `log_server-windows-dbms__v1_2023-05` (theoretical)
* `log_server-email__v1_2023-05` (theoretical)

* `log_server-anti-malware__v1_2023-05`
* `log_alerting__v1_2023`
  PagerDuty
* `log_monitoring-events__v1_2023-05`
* `log_monitoring-events_test=someIndexMappingChange_author=ypid__v1_2023-05`
* `log_monitoring-notifications__v1_2023`
* `log_monitoring-host-down-elapsed__v1_2023`
* `log_e2e-tests__v1_2023`

  Previously known as `ping-up-down-v7-2018.02`.

* `log_automation-log-collection__v1_2023`

  Intended for automation jobs in Elastic. For example data retention/deletion and snapshot creating and snapshot deletion.
  Previously known as `.curator-v7-2018`. In Elasticsearch, indices starting with a `.` are reserved for Elasticsearch itself. Automation tools for Elastic(search) are not contained in Elasticsearch so this reservation does not count here.

* `log_automation__v1_2023-05`
* `log_config-management__v1_2023-05`
* `log_issues__v1_2023`
* `log_issues_env=staging__v1_2023`

  Previous names considered: `log_report-aggregated-issues__v1_2023`, `log_filtered-aggregated-issues__v1_2023`
  Previously known as `critical-logs-v7-2018`.

  It resolves a conflicting meaning of "critical" because critical is already defined by [RFC 5424](https://tools.ietf.org/html/rfc5424#section-6.2.1) for the logging context.

* `log_test-something-something_author=ypid__v1_2023-05-23`

  For manual testing. The time range should be set to the current date.

* `metric_e2e-tests-crm__v1_2023-05-23`
* `metric_e2e-tests-km__v1_2023-05-23`
* `metric_e2e-tests-systemtesting__v1_2023-05-23`
* `metric_e2e-tests_env=dev__v1_2023-05-23`
* `metric_elastic-logstash__v1_2023`
  Custom Elastic metrics, for example: https://www.elastic.co/guide/en/logstash/current/plugins-filters-metrics.html

* `unknown_input__v1_2023`
  For unknown Logstash inputs. Reasons: unassigned category and source, unparsable JSON input.

Background:

The switch from hyphens to underscores as component separator has been done for the following reasons:

* Index names should contain a timestamp. For timestamps the universal standard is RFC 3339/ISO 8601 which uses hyphens.
* It has been used in the [Elasticsearch - The Definitive Guide](https://www.elastic.co/guide/en/elasticsearch/guide/current/time-based.html).


Refs: https://github.com/elastic/kibana/issues/2017#issuecomment-168816164

The category has been introduced to allow to have index templates which serve as a default for the category.

This also addresses the issue to only match custom indices using the [`index_patterns`](https://www.elastic.co/guide/en/elasticsearch/reference/6.2/indices-templates.html) and no hidden/system indices. There is currently no way to ensure this otherwise. Ref: https://github.com/elastic/elasticsearch/issues/17247

Example index patterns:

* `log_*`: Match all logs.
* `log_network-firewall-sessions_*`: Match all network-firewall-sessions logs. This would be the index pattern used in specific index templates.
* `log_network-firewall-sessions__*`: Match all production network-firewall-sessions logs. This would be the typical index pattern used in Kibana.
* `log_network-firewall-sessions__v1_`: Match all production network-firewall-sessions logs with index format version 1.
* `metric_e2e-tests_env=dev__*`: Match all production network-firewall-sessions logs with index format version 1.
* `*_*__v*_*` for use in index templates to catch all indices following v2 of the syntax.

Example saved searches, visualizations and dashboards:

It could make sense to include vendor names in parenthesizes to make it easier to find.

* `<department> log network-switch (HPE, Cisco)`
* `<department> log network-switch-management (HPE IMC)`
* `<department> log network-wan-optimization (Riverbed SteelHead)`
* `<department> log server-bmc (HPE iLO, FTS iRMC)`
* `<department> log automation-elastic (Elastic Curator)`
* `<department> log monitoring-host-down-elapsed (Swarm ping)`
* `<department> log issues (Aggregated issues in logs; previously known as critical-logs)`

Note that underscores are dropped because the word analyzer of ES considers two words joined by underscores as one token which would prevent you from searching for one of the words in the saved searches.

Example mapping optimization:

* Disable `_source` for all `metric_*`.
  https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping-source-field.html#_disabling_the_literal__source_literal_field


### Index format version:

Increment this if you make changes to field datatypes.
This is done for two reasons:

1. To make it possible in Kibana to create new index-patterns without conflicts.
2. To allow reindexing old indices into new once. This requires a new name.

Note that there is one downside to this. When you refer to a document in
another index with `{{index}}/{{_id}}`, the index will change and
the ref will not work anymore.

A alternative is to use index aliases.

## Elasticsearch field naming convention

[Elastic Common Schema](https://www.elastic.co/guide/en/ecs/current/index.html)
