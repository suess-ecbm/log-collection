CURL_OPTIONS ?= --cacert "$(shell get_es_cacert)" -XGET -u "$(shell get_es_creds)"
CURL_BASE_URL ?= $(shell get_es_url)

default: all

all: index_templates.json

.PHONY: FORCE_MAKE
FORCE_MAKE:

.PHONY: list_index_templates
list_index_templates:
	@jq '. | keys | .[]' index_templates.json --raw-output

index_templates.json: FORCE_MAKE
	curl $(CURL_OPTIONS) "$(CURL_BASE_URL)/_template/metric_e2e-tests?pretty" > "$@"

.PHONY: push-%
push-%:
	@jq '.["$(@:push-%=%)"]' "index_templates.json" | curl -XPOST $(CURL_OPTIONS) "$(CURL_BASE_URL)/_template/$(@:push-%=%)" -H "Content-Type: application/json" -d '@-'
	@echo ""

.PHONY: push-all
push-all:
	@for target in $$($(MAKE) --quiet list_index_templates); do $(MAKE) "push-$$target" || exit 1; done
