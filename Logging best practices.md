# Logging best practices

Status: draft, testing
Author: Robin Schneider

## Requirements

* Severity must be as specified in [RFC 5424 (section 6.2.1)](https://tools.ietf.org/html/rfc5424#section-6.2.1).
  Severity/Priority must either be the numerical code or a supported keyword as in https://en.wikipedia.org/wiki/Syslog#Severity_level
  It should be easily searchable e.g. the syslog formula is bad.
  See also: https://wiki.archlinux.org/index.php/Systemd/Journal#Priority_level
* Timestamp must be as specified in [RFC 5424 (section 6.2.3)](https://tools.ietf.org/html/rfc5424#section-6.2.3).
* Host must be as specified in [RFC 5424 (section 6.2.4)](https://tools.ietf.org/html/rfc5424#section-6.2.4).
* Multiline/Newline in message text. Think about stack traces!
* Structured data must be supported.
* Use a well-known logging framework for your programming language.
* LAN local logging. The application should not deal with sending logs over the network. Instead it should rely on the OS for this.
* LAN local caching: Some systems might not have local storage/persistent cache, in this case logs need to be send to a LAN local (syslog) relay.

### Remote logging in the application

This should only be implemented if there is a good reason for it. Otherwise remote logging should be handled by the OS.

* Transport over TCP must be supported.
* Transport over TLS and client certificates should be supported.
* (LAN) local caching should be supported.

## Existing standards

* [RFC 3164](https://tools.ietf.org/html/rfc3164)

  This is what most people (as of 2018) think when they say "syslog" because frankly, this is what is most often seen in the wild. It is only an informational RFC. Note that it is obsoleted by: RFC 5424. RFC 3164 has many issues: Bad time format, only requires fields on the protocol level are severity and facility. As said, this RFC is obsoleted and should go away.

  Example:

  ```
  <34>Oct 11 22:14:15 mymachine su: 'su root' failed for lonvick on /dev/pts/8
  <165> Jan 31 11:01:41,gnu.example.org,%DOT11-6-CLIENT_INFO:, Client '00-00-5E-00-53-00' IP address '192.0.2.1', bssid '00-00-5E-00-53-01' of radio 'gnu.example.org:R1' signal-strength -65dBm
  ```

* [RFC 5424](https://tools.ietf.org/html/rfc5424)

  RFC 5424 was standardized in 2009 and is pretty neat. It meets most of the requirements and is a good option for interoperable, standardized logging. It is the best specified option we have. RFC 5424 requires TLS to be supported (on top of TCP). UDP should be implemented.

  Advantages:

  * Well defined and reviewed.
  * Supports structured data.
  * It does not simply support structured data, but specifies some standard additional information that can be logged like info on the timeQuality, origin and meta (ref: https://www.iana.org/assignments/syslog-parameters/syslog-parameters.xhtml#syslog-parameters-4).
  * Allows to register an enterpriseId and then define exactly what fields actually mean like in SNMP. But there is no MIB format defined as in SNMP unfortunately? At least the IANA reviews the usage of SD-INs and SD-PARAMs.
  * Requires TLS support and defines whys to ensure authenticated log transport as part of [RFC 5425](https://tools.ietf.org/html/rfc5425).

  Disadvantages:

  * Severity is not human readable! Proposed solution when storing as log file: Include the severity keyword in the MSG, example: "warn: This is a warning". When parsing the RFC 5424 event, the severity keyword in the MSG, if contained, is stripped again.
  * No multiline support. There are ways to make it work, ref: [RFC 6587](https://tools.ietf.org/html/rfc6587) but the tooling might have issues with it. Potentially use "\n" (two characters) to escape newlines.
  * Very little adaption as of 2018. With noticeable exceptions, refer to the [Hall of fame](hall-of-fame).
  * To follow the standard for outputting structured data, one would need an enterpriseId. As Geberit does not have one, the proposed solution is to use 523425 which is easy to find and replace later.

  Example:

  ```
  <165>1 2007-02-15T09:17:15.719+01:00 router1 mgd 3046 UI_DBASE_LOGOUT_EVENT [timeQuality tzKnown="1" isSynced="1"][origin ip="192.0.2.1" ip="192.0.2.129"][junos@2636.1.1.1.2.18 username="gnu"] User 'gnu' exiting configuration mode.
  ```

* Often recommended: Use JSON!

  Advantages:

  * Multiline support.
  * (deeply nested) structured data.

  Disadvantages:

  * No standards of structured data (the field names and meanings are not defined).

  Example:

  ```json
  {
    "@metadata": {
      "pre_filters": [
        "python-logging"
      ]
    },
    "data": {
      "e2e-sikulix_example-x-process_time": 13.28600001335144
    },
    "level": "INFO",
    "#logstash_timestamp": "2018-01-17T14:56:40.342Z",
    "message": "sikulix_example Sikulix test workflow completed sucessfully",
    "type": "raw_event",
    "env": {
      "managed_network": true,
      "os_family": "Windows",
      "distribution_full_name": "Windows 10.0",
      "location_code": "xxxx",
      "user_name": "user",
      "managed_software": true,
      "distribution": "Windows",
      "distribution_major_version": "10.0"
    },
    "tags": [],
    "path": "c:\\perf\\crm_browser.sikuli\\crm_browser.py",
    "@timestamp": "2018-01-17T14:56:40.342Z",
    "#source": "e2e-tests",
    "port": 56690,
    "meta": {
      "test": "sikulix_example",
      "version": "0.2.0",
      "commit_hash": "30903138bfa08b558b61cb30999c5b8cf2896904",
      "uncommited_changes": true
    },
    "@version": "1",
    "host": "gnu.example.org",
    "logger_name": "python-logstash-logger"
  }
  ```

* Often seen in the wild: RFC 3164 with some form of key value pairs or csv.

  Provides no advantage over RFC 5424.

  Example:

  ```
  <134>May  1 10:23:43 filterlog: 112,,,0,lagg0_vlan2342,match,block,in,4,0x0,,64,16940,0,DF,17,udp,58,192.0.2.23,192.0.2.42,2069,53,38
  <134>May  1 15:11:01 filterlog: 112,,,0,em0,match,block,in,4,0xc0,,1,0,0,DF,2,igmp,36,192.0.2.50,224.0.0.1,datalength=12
  <134>May  1 15:11:01 filterlog: 112,,,0,em0,match,block,in,4,0xc0,,1,0,0,DF,2,igmp,36,8.8.8.8,193.99.144.80,datalength=12
  ```

* Elastic beats/Elastic Common Schema (ECS)

  https://github.com/elastic/ecs

  * Multiline support.
  * (deeply nested) structured data.
  * New and active.

* Lumberjack

  Advantages:

  * Multiline support.
  * (deeply nested) structured data.
  * At least some fields "standardized". Better than with reinventing your own JSON based data-structure.

  Disadvantages:

  * Library is not contained in Debian anymore because of lack of interest.
  * Last activity 2012.

  https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/system_administrators_guide/s1-structured_logging_with_rsyslog#s2-filtering_structured_messages
  https://github.com/deirf/libumberlog

  Example:

  ```
  Mar 24 12:01:34 localhost sshd[12590]: @cee:{
      "msg": "Accepted publickey for algernon from 127.0.0.1 port 55519 ssh2",
      "pid": "12590", "facility": "auth", "priority": "info",
      "program": "sshd", "uid": "0", "gid": "0",
      "host": "hadhodrond", "timestamp": "2012-03-24T12:01:34.236987887+0100" }
  ```

* CEFLogging

  Disadvantages:

  * Timestamp format.

  https://support.citrix.com/article/CTX136146

  Example:

  ```
  Dec 18 20:37:08 <local0.info> 10.217.31.247 CEF:0|Citrix|NetScaler|NS10.0|APPFW|APPFW_STARTURL|6|src=10.217.253.78 spt=53743 method=GET request=http://vpx247.example.net/FFC/login.html msg=Disallow Illegal URL. cn1=233 cn2=205 cs1=profile1 cs2=PPE0 cs3=AjSZM26h2M+xL809pON6C8joebUA000 cs4=ALERT cs5=2012 act=blocked
  ```

* Graylog Extended Log Format (GELF)

  Advantages:

  * Has found some adaption.
  * Supports structured data.
  * Multiline support.
  * Facility field is not required anymore.

  Disadvantages:

  * Timestamp format is not human readable. Workarounds: https://github.com/severb/graypy/issues/99.
  * TLS not supported.

  http://docs.graylog.org/en/2.5/pages/gelf.html#gelf-payload-specification

  ```json
  {
    "version": "1.1",
    "host": "example.org",
    "short_message": "A short message that helps you identify what is going on",
    "full_message": "Backtrace here\n\nmore stuff",
    "timestamp": 1385053862.3072,
    "level": 1,
    "_user_id": 9001,
    "_some_info": "foo",
    "_some_env_var": "bar"
  }
  ```

* systemd-journald

  Works nicely when combined with python-systemd and journalbeat.

## Conclusion

What "standard" to use while keeping our requirements as specified in this document in mind:

1. Use the standard of the platform/language if they meet the requirements. Approved are: systemd-journald, Windows Event log, SAP application log.
2. RFC 5424 is preferred. Especially appliances should be configured to RFC 5424 if possible. If not supported, vendors should be requested to implement it.
3. Applications and scripts might send ECS log events if they need multiline support. (Beta)

## Hall of fame

* Juniper Networks seems to fully support RFC 5424. Ref: https://www.juniper.net/documentation/en_US/junos/topics/task/configuration/syslog-message-structured-data-format-qfx-series-.html
* systemd on GNU/Linux: Fully supports RFC 5424. `logger`, `systemd-netlogd`. Ref: https://github.com/systemd/systemd-netlogd

## Program specific

### Rsyslog

The following template can be used in Rsyslog to output ECS. It has been tested with Rsyslog 3.3 and up.

```
template(name="ecs_1.0.1" type="list") {
    constant(value="{")
    property(outname="@timestamp" name="timereported" dateFormat="rfc3339" format="jsonf")
    constant(value=",\"event\":{")
    property(outname="created" name="timegenerated" dateFormat="rfc3339" format="jsonf")
    constant(value=",")
    property(outname="severity" name="syslogseverity" format="jsonf")
    constant(value="},\"syslog\":{")
    property(outname="facility_label" name="syslogfacility-text" format="jsonf")
    constant(value="},\"host\":{")
    property(outname="name" name="hostname" format="jsonf")
    constant(value=",")
    property(outname="ip" name="fromhost-ip" format="jsonf")
    constant(value="},\"ecs\":{")
    constant(value="\"version\":\"1.0.1\"")
    constant(value="},")
    ## TODO: rawmsg-after-pri is preferred but was only "recently" introduced with 8.14.0.
    property(outname="message" name="rawmsg" format="jsonf"
             controlcharacters="escape"
             # regex.type="ERE"
             # regex.submatch="1"
             # regex.nomatchmode="FIELD"
             # regex.expression="(.*) *matched_pattern=\"bytes=.*"
    )
    constant(value="}\n")
}
```

## Language specific

### Python

Use the `logging` module. With that foundation, you can then use one (or all) of the following. Just remember to emit structured data using the `extra` parameter.

1. https://github.com/systemd/python-systemd

   Refer to https://github.com/systemd/python-systemd/issues/69 for details.

  ```Python
  {
    "__CURSOR": "s=39ea0577ca1a4eeba133c26acca6c8e1;i=3cb001;b=9528b546a81f4c07bc72864197ac5831;m=143e68fd179;t=58653aa5a174e;x=f3f3fd4b4cca9b4b",
    "__REALTIME_TIMESTAMP": "1555068781991758",
    "__MONOTONIC_TIMESTAMP": "1391142621561",
    "_BOOT_ID": "9528b546a81f4c07bc72864197ac5831",
    "_MACHINE_ID": "9a07ab6e06a4458caed1128e5be1a36a",
    "_HOSTNAME": "gdepfh6s",
    "PRIORITY": "6",
    "CODE_LINE": "511",
    "CODE_FUNC": "<module>",
    "THREAD_NAME": "MainThread",
    "_TRANSPORT": "journal",
    "_UID": "0",
    "_GID": "0",
    "_COMM": "suma_channel_au",
    "_EXE": "/usr/bin/python3.4",
    "_CMDLINE": "/usr/bin/python3 ./suma_channel_automater --stage create_activation_keys -n -d",
    "_CAP_EFFECTIVE": "3fffffffff",
    "_SYSTEMD_CGROUP": "/user.slice/user-0.slice/session-1.scope",
    "_SYSTEMD_SESSION": "1",
    "_SYSTEMD_OWNER_UID": "0",
    "_SYSTEMD_UNIT": "session-1.scope",
    "_SYSTEMD_SLICE": "user-0.slice",
    "CODE_FILE": "./suma_channel_automater",
    "SYSLOG_IDENTIFIER": "./suma_channel_automater",
    "PROCESS_NAME": "MainProcess",
    "LOGGER": "__main__",
    "MESSAGE": "test",
    "TEST": "[23, 42]",
    "_PID": "24394",
    "_SOURCE_REALTIME_TIMESTAMP": "1555068781991520"
  }
  ```Python

2. https://pypi.org/project/cysystemd/

  ```Python
  {
    "__CURSOR": "s=39ea0577ca1a4eeba133c26acca6c8e1;i=3cba4f;b=9528b546a81f4c07bc72864197ac5831;m=1441f45da0f;t=58653e3101fe4;x=c6638cd6a744e660",
    "__REALTIME_TIMESTAMP": "1555069733445604",
    "__MONOTONIC_TIMESTAMP": "1392094075407",
    "_BOOT_ID": "9528b546a81f4c07bc72864197ac5831",
    "_MACHINE_ID": "9a07ab6e06a4458caed1128e5be1a36a",
    "_HOSTNAME": "gdepfh6s",
    "PRIORITY": "6",
    "CODE_LINE": [
      "511",
      "57"
    ],
    "CODE_MODULE": "suma_channel_automater",
    "SYSLOG_IDENTIFIER": "__main__",
    "PATHNAME": "./suma_channel_automater",
    "ERRNO": "0",
    "CODE_FUNC": [
      "<module>",
      "__pyx_f_9cysystemd_8_journal__send"
    ],
    "THREAD_NAME": "MainThread",
    "CODE_FILE": [
      "suma_channel_automater",
      "cysystemd/_journal.pyx"
    ],
    "PROCCESS_NAME": "MainProcess",
    "SYSLOG_FACILITY": "Facility.DAEMON",
    "LOGGER_NAME": "__main__",
    "_TRANSPORT": "journal",
    "_UID": "0",
    "_GID": "0",
    "_COMM": "suma_channel_au",
    "_EXE": "/usr/bin/python3.4",
    "_CMDLINE": "/usr/bin/python3 ./suma_channel_automater --stage create_activation_keys -n -d",
    "_CAP_EFFECTIVE": "3fffffffff",
    "_SYSTEMD_CGROUP": "/user.slice/user-0.slice/session-1.scope",
    "_SYSTEMD_SESSION": "1",
    "_SYSTEMD_OWNER_UID": "0",
    "_SYSTEMD_UNIT": "session-1.scope",
    "_SYSTEMD_SLICE": "user-0.slice",
    "LEVELNAME": "INFO",
    "MESSAGE": "test",
    "TEST": "[23, 42]",
    "PID": "25458",
    "MSECS": "445.03021240234375",
    "RELATIVE_TS": "43664693",
    "CREATED": "1555069733.4450302",
    "THREAD": "140716412086016",
    "MESSAGE_ID": "60114bca1e4f3b08a7196e2e726402c4",
    "MESSAGE_RAW": "test",
    "_PID": "25458",
    "_SOURCE_REALTIME_TIMESTAMP": "1555069733445359"
  }
  ```

3. https://github.com/severb/graypy
4. https://github.com/keeprocking/pygelf
5. https://github.com/jobec/rfc5424-logging-handler

   Standard format, might be possible to write to a local syslog server for buffering.

6. https://github.com/eht16/python-logstash-async

   Supports buffering in local sqlite db file. Used by https://github.com/geberit/e2e-tests.

7. https://www.structlog.org/en/stable/index.html

### MS Shell (PowerShell)

1. https://github.com/iRon7/Log-Entry

2. https://github.com/iRon7/Log-Entry

3. Just use the Windows event log using the Write-Log function. Refer to logging_examples/logging_example_script.ps1.

   https://blogs.technet.microsoft.com/heyscriptingguy/2013/06/20/how-to-use-powershell-to-write-to-event-logs/

4. https://github.com/poshsecurity/Posh-SYSLOG

5. https://github.com/jeremymcgee73/PSGELF

## References

* https://dev.splunk.com/view/logging/SP-CAAAFCK
* https://logmatic.io/blog/python-logging-with-json-steroids/
* https://www.bouncybouncy.net/blog/syslog-is-terrible/
