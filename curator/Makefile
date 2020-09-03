## Don't write long scripts when jq/yq one-liners are all that is needed! And don't do it manually obviously.

.SILENT:

.PHONY: docs
docs:
	$(MAKE) docs-csv | csvtool readable -

.PHONY: docs-csv
docs-csv:
	yq '.actions | to_entries | map({retention_days: (.key | split(" ") | .[0]), index_rollover_interval: (.key | split(" ") | .[2]), index_pattern: (.value.filters[] | select(.filtertype == "pattern" and .exclude != true) | .value )}) | (.[0] | keys_unsorted) as $$keys | $$keys, map([.[ $$keys[] ]])[] | @csv' delete_indices.yml --raw-output


delete_indices_no_upper_filter.yml:
%_no_upper_filter.yml: %.yml Makefile
	yq '.actions = ( .actions | with_entries(.value.filters = ( .value.filters | map(select( (.filtertype == "age" and .direction == "younger") | not )) ) ) )' "$<" --yaml-output > "$@"

.PHONY: logs
logs: /var/log/curator/curator.json
	jq '.["@timestamp"] + ": " + .loglevel + " " + .message' "$<" --raw-output
