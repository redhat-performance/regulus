# REPORT/Makefile
# Central makefile for all report-related operations
# Delegates to build_report/Makefile for dashboard and ElasticSearch operations

.PHONY: help summary summary-with-testbed-info dashboard dashboard-stop dashboard-restart dashboard-status \
        flatten flatten-pretty es-upload es-template es-check es-full \
        es-index-stats es-template-info es-index-mapping \
        es-ilm-policy es-ilm-policy-no-delete es-ilm-info es-ilm-explain es-bootstrap-index \
        es-list-batches es-batch-count es-batch-info es-delete-batch es-show-last-batch es-list-execution-labels \
        es-delete-index \
        clean

# Configuration
PYTHON := python3
BUILD_REPORT_DIR := build_report
DASHBOARD_DIR := dashboard
ES_INTEGRATION_DIR := es_integration
REPORT_DIR := $(shell pwd)
GENERATED_DIR := $(REPORT_DIR)/generated
REG_ROOT ?= $(shell cd .. && pwd)

# ElasticSearch index configuration (matches es_config.py)
# BASE_NAME: Infrastructure constant for rollover index names (regulus-results-000001, 000002, etc.)
# ES_INDEX: Query pattern for reading data across all rollover indices
# ES_WRITE_ALIAS: Write alias pointing to current hot index for uploads
BASE_NAME ?= regulus-results
ES_INDEX ?= regulus-results-*
ES_WRITE_ALIAS ?= regulus-results-write

# Helper to sanitize ES_URL for display (removes credentials)
# Usage: echo $$(echo "$$ES_URL" | $(SANITIZE_URL))
SANITIZE_URL = sed -E 's|(https?://)([^:]+):([^@]+)@|\1***:***@|'

# Helper to determine ES_URL with priority: env > /secret > lab.config
# Usage: @$(SOURCE_ES_CONFIG); your_command_using_$$ES_URL
# Note: This exports ES_URL for use in subprocesses
SOURCE_ES_CONFIG = \
	if [ -n "$${ES_URL:-}" ]; then \
		export ES_URL; \
	elif [ -d "/secret" ]; then \
		ES_USER=$$(cat /secret/username 2>/dev/null || echo ""); \
		ES_PASSWORD=$$(cat /secret/password 2>/dev/null || echo ""); \
		ES_HOST=$$(cat /secret/host 2>/dev/null || echo ""); \
		if [ -z "$$ES_HOST" ]; then \
			echo "ERROR: /secret/host is empty or not readable"; \
			exit 1; \
		fi; \
		if [ -n "$$ES_USER" ] && [ -n "$$ES_PASSWORD" ]; then \
			export ES_URL="https://$${ES_USER}:$${ES_PASSWORD}@$${ES_HOST}"; \
		else \
			export ES_URL="https://$${ES_HOST}"; \
		fi; \
	elif [ -f "$(REG_ROOT)/lab.config" ]; then \
		. $(REG_ROOT)/lab.config; \
		if [ -z "$${ES_URL:-}" ]; then \
			echo "ERROR: lab.config must define ES_URL"; \
			exit 1; \
		fi; \
		export ES_URL; \
	else \
		echo "ERROR: No ES configuration found."; \
		echo "  - No ES_URL environment variable"; \
		echo "  - No /secret/ directory (Kubernetes secrets)"; \
		echo "  - No $(REG_ROOT)/lab.config file"; \
		exit 1; \
	fi

# Default target
help:
	@echo "====================================================================="
	@echo "  REPORT - Regulus Benchmark Report Generation and Analysis"
	@echo "====================================================================="
	@echo ""
	@echo "Report Generation:"
	@echo "  make summary              - Generate report (unflatten + flatten outputs)"
	@echo "  make summary-with-testbed-info - Generate report with testbed info"
	@echo ""
	@echo "Dashboard & Visualization:"
	@echo "  make dashboard            - Start interactive web dashboard"
	@echo "  make dashboard-stop       - Stop dashboard instances"
	@echo "  make dashboard-restart    - Restart dashboard"
	@echo ""
	@echo "ElasticSearch Integration:"
	@echo "  make flatten              - Flatten existing report.json (or run summary)"
	@echo "  make flatten-pretty       - Create human-readable JSON"
	@echo "  make es-template          - Apply ES index template"
	@echo "  make es-upload            - Upload reports.ndjson to ElasticSearch"
	@echo "  make es-full              - Complete ES workflow (summary → template → upload)"
	@echo ""
	@echo "ElasticSearch Debug & Info:"
	@echo "  make es-index-stats       - Show ES index statistics"
	@echo "  make es-template-info     - Show ES index template details"
	@echo "  make es-index-mapping     - Show current index mapping"
	@echo ""
	@echo "Index Lifecycle Management (ILM):"
	@echo "  make es-ilm-policy            - Apply ILM policy (with 90-day deletion)"
	@echo "  make es-ilm-policy-no-delete  - Apply ILM policy (NO deletion, for CCR)"
	@echo "  make es-ilm-info              - Show current ILM policy details"
	@echo "  make es-ilm-explain           - Explain ILM phase for index"
	@echo "  make es-bootstrap-index       - Create bootstrapped rollover index"
	@echo ""
	@echo "Batch Management:"
	@echo "  make es-list-batches                     - List all upload batches"
	@echo "  make es-batch-count ES_BATCH_ID=<uuid>   - Count documents in batch"
	@echo "  make es-batch-info ES_BATCH_ID=<uuid>    - Show batch details"
	@echo "  make es-delete-batch ES_BATCH_ID=<uuid>  - Delete all documents in batch"
	@echo "  make es-show-last-batch                  - Show most recent batch"
	@echo "  make es-list-execution-labels            - List all execution_label values"
	@echo ""
	@echo "Configuration:"
	@echo "  REG_ROOT        = $(REG_ROOT)"
	@echo "  ES_URL          = Set by caller (from lab.config or environment)"
	@echo "  BASE_NAME       = $(BASE_NAME)"
	@echo "  ES_INDEX        = $(ES_INDEX) (query pattern)"
	@echo "  ES_WRITE_ALIAS  = $(ES_WRITE_ALIAS) (upload target)"
	@echo "====================================================================="

# =============================================================================
# Report Generation Targets
# =============================================================================

summary:
	@echo "Creating generated directory if needed..."
	@mkdir -p $(GENERATED_DIR)
	@# Backup report-with-testbed-info.json if it exists (to avoid dashboard duplicates)
	@if [ -f "$(GENERATED_DIR)/report-with-testbed-info.json" ]; then \
		echo "Backing up report-with-testbed-info.json to report-with-testbed-info.json.bak"; \
		mv -f "$(GENERATED_DIR)/report-with-testbed-info.json" "$(GENERATED_DIR)/report-with-testbed-info.json.bak"; \
	fi
	@echo "Generating unflatten report (report.json, HTML, CSV) in REPORT/generated/..."
	@cd $(REG_ROOT) && REG_ROOT=$(REG_ROOT) bash REPORT/$(BUILD_REPORT_DIR)/build_report --formats html csv --output REPORT/generated/report
	@echo ""
	@echo "Flattening report.json to NDJSON for ElasticSearch..."
	@$(PYTHON) $(ES_INTEGRATION_DIR)/flatten_to_es.py $(GENERATED_DIR)/report.json -o $(GENERATED_DIR)/reports.ndjson --es-index $(ES_WRITE_ALIAS)
	@echo ""
	@echo "✓ Report generation complete:"
	@echo "  - Unflatten: $(GENERATED_DIR)/report.json"
	@echo "  - Flatten:   $(GENERATED_DIR)/reports.ndjson"
	@ls -lh $(GENERATED_DIR)/report.json $(GENERATED_DIR)/reports.ndjson 2>/dev/null || true

summary-with-testbed-info:
	@mkdir -p $(GENERATED_DIR)
	@# First generate base report.json if it doesn't exist
	@if [ ! -f "$(GENERATED_DIR)/report.json" ]; then \
		echo "Base report.json not found. Generating it first..."; \
		echo ""; \
		cd $(REG_ROOT) && REG_ROOT=$(REG_ROOT) bash REPORT/$(BUILD_REPORT_DIR)/build_report --formats html csv --output REPORT/generated/report; \
		echo ""; \
	fi
	@echo "Generating report with testbed info..."
	@cd $(REG_ROOT) && REG_ROOT=$(REG_ROOT) bash REPORT/assembly/assemble_report.sh
	@echo ""
	@echo "Flattening report-with-testbed-info.json to NDJSON for ElasticSearch..."
	@$(PYTHON) $(ES_INTEGRATION_DIR)/flatten_to_es.py $(GENERATED_DIR)/report-with-testbed-info.json -o $(GENERATED_DIR)/reports-with-testbed-info.ndjson --es-index $(ES_WRITE_ALIAS)
	@echo ""
	@echo "✓ Report with testbed info generation complete:"
	@echo "  - Unflatten: $(GENERATED_DIR)/report-with-testbed-info.json"
	@echo "  - Flatten:   $(GENERATED_DIR)/reports-with-testbed-info.ndjson"
	@ls -lh $(GENERATED_DIR)/report-with-testbed-info.json $(GENERATED_DIR)/reports-with-testbed-info.ndjson 2>/dev/null || true

# =============================================================================
# Dashboard Targets
# =============================================================================

dashboard:
	@echo "Starting dashboard with reports from: $(GENERATED_DIR)"
	@$(PYTHON) $(DASHBOARD_DIR)/run_dashboard.py --reports $(GENERATED_DIR)

dashboard-stop:
	@echo "Stopping dashboard instances..."
	@ps aux | grep "$(DASHBOARD_DIR)/run_dashboard.py" | grep -v grep | awk '{print $$2}' | xargs kill 2>/dev/null || echo "No dashboard instances running"

dashboard-restart: dashboard-stop
	@sleep 2
	@echo "Restarting dashboard..."
	@$(MAKE) dashboard

dashboard-status:
	@echo "Dashboard Status:"
	@ps aux | grep "$(DASHBOARD_DIR)/run_dashboard.py" | grep -v grep || echo "  No dashboard instances running"

# =============================================================================
# ElasticSearch Targets
# =============================================================================

# Flatten report.json to NDJSON format
# Note: 'make summary' already generates both unflatten and flatten outputs
# This target is kept for backward compatibility
flatten:
	@mkdir -p $(GENERATED_DIR)
	@if [ ! -f "$(GENERATED_DIR)/report.json" ]; then \
		echo "report.json not found. Running 'make summary' to generate both outputs..."; \
		$(MAKE) summary; \
	else \
		echo "Flattening existing report.json..."; \
		$(PYTHON) $(ES_INTEGRATION_DIR)/flatten_to_es.py $(GENERATED_DIR)/report.json -o $(GENERATED_DIR)/reports.ndjson --es-index $(ES_WRITE_ALIAS); \
		echo "✓ Flatten complete: $(GENERATED_DIR)/reports.ndjson"; \
	fi

# Create human-readable pretty JSON
flatten-pretty: flatten
	@if [ ! -f "$(GENERATED_DIR)/reports.ndjson" ]; then \
		echo "Error: $(GENERATED_DIR)/reports.ndjson does not exist"; \
		echo "Run 'make flatten' first to generate the NDJSON file"; \
		exit 1; \
	fi
	@echo "Creating pretty-printed version of flattened data..."
	@grep -v '{"index"' $(GENERATED_DIR)/reports.ndjson | $(PYTHON) -c "import sys, json; docs = [json.loads(line) for line in sys.stdin if line.strip()]; print(json.dumps(docs, indent=2))" > $(GENERATED_DIR)/reports_pretty.json
	@echo "✓ Pretty-printed JSON saved to: $(GENERATED_DIR)/reports_pretty.json"
	@ls -lh $(GENERATED_DIR)/reports_pretty.json

# ElasticSearch operations
es-check:
	@$(SOURCE_ES_CONFIG); \
	SAFE_URL=$$(echo "$$ES_URL" | $(SANITIZE_URL)); \
	echo "Checking ElasticSearch connection at $$SAFE_URL..."; \
	curl -s "$${ES_URL}" > /dev/null && \
		echo "✓ ElasticSearch is reachable at $$SAFE_URL" || \
		echo "✗ Cannot connect to ElasticSearch at $$SAFE_URL"

es-template: es-check
	@$(SOURCE_ES_CONFIG); \
	echo "Detecting platform and applying index template..."; \
	PLATFORM_VARS=$$(export ES_URL="$${ES_URL}"; bash $(ES_INTEGRATION_DIR)/detect_platform.sh 2>&1); \
	if [ $$? -ne 0 ]; then \
		echo "ERROR: Failed to detect platform"; \
		echo "$$PLATFORM_VARS"; \
		exit 1; \
	fi; \
	eval "$$PLATFORM_VARS"; \
	echo "Detected platform: $$PLATFORM (version $$VERSION)"; \
	echo "Applying template: $$TEMPLATE_FILE"; \
	echo ""; \
	curl -X PUT "$${ES_URL}/_index_template/regulus-template" \
		-H 'Content-Type: application/json' \
		-d @$(ES_INTEGRATION_DIR)/$${TEMPLATE_FILE} | $(PYTHON) -m json.tool; \
	echo ""; \
	echo "✓ Index template applied successfully"; \
	echo "  Platform: $$PLATFORM"; \
	echo "  Template: $$TEMPLATE_FILE"

es-upload:
	@if [ ! -f "$(GENERATED_DIR)/reports.ndjson" ]; then \
		echo "reports.ndjson not found. Running 'make summary' to generate it..."; \
		$(MAKE) summary; \
	fi
	@$(SOURCE_ES_CONFIG); \
	SAFE_URL=$$(echo "$$ES_URL" | $(SANITIZE_URL)); \
	echo "Uploading reports to ElasticSearch..."; \
	echo "  Source: $(GENERATED_DIR)/reports.ndjson"; \
	echo "  ES URL: $$SAFE_URL"; \
	echo "  Write Alias: $(ES_WRITE_ALIAS)"; \
	echo "Uploading $$(grep -c '{"index"' $(GENERATED_DIR)/reports.ndjson 2>/dev/null || echo 0) documents..."; \
	curl -s -H "Content-Type: application/x-ndjson" \
		-XPOST "$${ES_URL}/$(ES_WRITE_ALIAS)/_bulk" \
		--data-binary @$(GENERATED_DIR)/reports.ndjson | \
		$(PYTHON) $(ES_INTEGRATION_DIR)/debug_upload_errors.py

# Complete ElasticSearch workflow
es-full: summary es-template es-upload
	@echo ""
	@echo "✓ Complete ElasticSearch workflow finished:"
	@echo "  - Report generated: $(GENERATED_DIR)/report.json"
	@echo "  - Flattened to: $(GENERATED_DIR)/reports.ndjson"
	@echo "  - Uploaded to ES write alias: $(ES_WRITE_ALIAS)"
	@echo ""
	@echo "NOTE: ISM policy auto-attached via ism_template during es-bootstrap-index"

# =============================================================================
# ElasticSearch Debug and Info Targets
# =============================================================================

es-index-stats: es-check
	@$(SOURCE_ES_CONFIG); \
	SAFE_URL=$$(echo "$$ES_URL" | $(SANITIZE_URL)); \
	echo "=========================================="; \
	echo "  ElasticSearch Index Statistics"; \
	echo "=========================================="; \
	echo ""; \
	echo "Index: $(ES_INDEX)"; \
	echo "URL: $$SAFE_URL"; \
	echo ""; \
	echo "Detailed Stats (verbose):"; \
	curl -s "$${ES_URL}/_cat/indices/$(ES_INDEX)?v&h=health,status,index,uuid,pri,rep,docs.count,docs.deleted,store.size,pri.store.size"; \
	echo ""; \
	echo ""; \
	echo "Index Settings and Stats (JSON):"; \
	curl -s "$${ES_URL}/$(ES_INDEX)/_stats" | $(PYTHON) -m json.tool 2>/dev/null || echo "Index may not exist yet"

es-template-info: es-check
	@$(SOURCE_ES_CONFIG); \
	SAFE_URL=$$(echo "$$ES_URL" | $(SANITIZE_URL)); \
	echo "=========================================="; \
	echo "  ElasticSearch Index Template Info"; \
	echo "=========================================="; \
	echo ""; \
	echo "Template: regulus-template"; \
	echo "URL: $$SAFE_URL"; \
	echo ""; \
	curl -s "$${ES_URL}/_index_template/regulus-template" | $(PYTHON) -m json.tool 2>/dev/null || echo "Template does not exist. Run 'make es-template' to create it."

es-index-mapping: es-check
	@$(SOURCE_ES_CONFIG); \
	SAFE_URL=$$(echo "$$ES_URL" | $(SANITIZE_URL)); \
	echo "=========================================="; \
	echo "  ElasticSearch Index Mapping"; \
	echo "=========================================="; \
	echo ""; \
	echo "Index: $(ES_INDEX)"; \
	echo "URL: $$SAFE_URL"; \
	echo ""; \
	curl -s "$${ES_URL}/$(ES_INDEX)/_mapping" | $(PYTHON) -m json.tool 2>/dev/null || echo "Index does not exist yet"

# =============================================================================
# Batch Management Targets
# =============================================================================

es-list-batches: es-check
	@$(SOURCE_ES_CONFIG); \
	echo "=========================================="; \
	echo "  Upload Batches in $(ES_INDEX)"; \
	echo "=========================================="; \
	echo ""; \
	curl -s "$${ES_URL}/$(ES_INDEX)/_search?size=0&pretty" \
		-H 'Content-Type: application/json' \
		-d '{"aggs": {"batches": {"terms": {"field": "batch_id.keyword", "size": 100, "order": {"_key": "desc"}}}}}' | \
		$(PYTHON) -c 'import sys, json; \
		data = json.load(sys.stdin); \
		buckets = data.get("aggregations", {}).get("batches", {}).get("buckets", []); \
		print("Found {} unique batch(es):\n".format(len(buckets))); \
		[print("  {} ({} documents)".format(b["key"], b["doc_count"])) for b in buckets]'

es-batch-count: es-check
	@if [ -z "$(ES_BATCH_ID)" ]; then \
		echo "ERROR: ES_BATCH_ID required. Usage: make es-batch-count ES_BATCH_ID=<uuid>"; \
		exit 1; \
	fi
	@$(SOURCE_ES_CONFIG); \
	curl -s "$${ES_URL}/$(ES_INDEX)/_count?pretty" \
		-H 'Content-Type: application/json' \
		-d '{"query": {"term": {"batch_id.keyword": "$(ES_BATCH_ID)"}}}' | \
		$(PYTHON) -c 'import sys, json; print("Documents in batch: {}".format(json.load(sys.stdin)["count"]))'

es-batch-info: es-check
	@if [ -z "$(ES_BATCH_ID)" ]; then \
		echo "ERROR: ES_BATCH_ID required. Usage: make es-batch-info ES_BATCH_ID=<uuid>"; \
		exit 1; \
	fi
	@$(SOURCE_ES_CONFIG); \
	echo "=========================================="; \
	echo "  Batch Information"; \
	echo "=========================================="; \
	echo ""; \
	echo "Batch ID: $(ES_BATCH_ID)"; \
	echo "Index: $(ES_INDEX)"; \
	echo ""; \
	curl -s "$${ES_URL}/$(ES_INDEX)/_search?size=5&pretty" \
		-H 'Content-Type: application/json' \
		-d '{"query": {"term": {"batch_id.keyword": "$(ES_BATCH_ID)"}}, "aggs": {"benchmarks": {"terms": {"field": "benchmark"}}, "models": {"terms": {"field": "model"}}}}' | \
		$(PYTHON) -m json.tool

es-delete-batch: es-check
	@if [ -z "$(ES_BATCH_ID)" ]; then \
		echo "ERROR: ES_BATCH_ID required. Usage: make es-delete-batch ES_BATCH_ID=<uuid>"; \
		exit 1; \
	fi
	@$(SOURCE_ES_CONFIG); \
	echo "=========================================="; \
	echo "  WARNING: Delete Batch"; \
	echo "=========================================="; \
	echo ""; \
	echo "This will DELETE all documents with batch_id=$(ES_BATCH_ID)"; \
	echo "Index: $(ES_INDEX)"; \
	echo ""; \
	$(MAKE) es-batch-count ES_BATCH_ID=$(ES_BATCH_ID); \
	echo ""; \
	read -p "Are you sure you want to delete this batch? [y/N] " confirm && [ "$$confirm" = "y" ] || (echo "Cancelled."; exit 1); \
	echo ""; \
	echo "Deleting batch..."; \
	curl -s -X POST "$${ES_URL}/$(ES_INDEX)/_delete_by_query?pretty" \
		-H 'Content-Type: application/json' \
		-d '{"query": {"term": {"batch_id.keyword": "$(ES_BATCH_ID)"}}}' | \
		$(PYTHON) -m json.tool; \
	echo ""; \
	echo "✓ Batch deleted"

es-show-last-batch: es-check
	@$(SOURCE_ES_CONFIG); \
	echo "Most recent upload batch:"; \
	curl -s "$${ES_URL}/$(ES_INDEX)/_search?size=0&pretty" \
		-H 'Content-Type: application/json' \
		-d '{"aggs": {"latest": {"terms": {"field": "batch_id.keyword", "size": 1, "order": {"max_timestamp": "desc"}}, "aggs": {"max_timestamp": {"max": {"field": "@timestamp"}}}}}}' | \
		$(PYTHON) -c 'import sys, json; \
		data = json.load(sys.stdin); \
		buckets = data.get("aggregations", {}).get("latest", {}).get("buckets", []); \
		print("Batch ID: {}".format(buckets[0]["key"]) if buckets else "No batches found"); \
		print("Documents: {}".format(buckets[0]["doc_count"]) if buckets else ""); \
		print("Last upload: {}".format(buckets[0]["max_timestamp"]["value_as_string"]) if buckets else "")'

es-list-execution-labels: es-check
	@$(SOURCE_ES_CONFIG); \
	echo "==========================================" ;\
	echo "  Execution Labels in $(ES_INDEX)" ;\
	echo "==========================================" ;\
	echo "" ;\
	curl -s "$${ES_URL}/$(ES_INDEX)/_search?size=0&pretty" \
		-H 'Content-Type: application/json' \
		-d '{"aggs": {"execution_labels": {"terms": {"field": "execution_label", "size": 100, "missing": "__NULL__"}}}}' | \
		$(PYTHON) -c 'import sys, json; data = json.load(sys.stdin); buckets = data.get("aggregations", {}).get("execution_labels", {}).get("buckets", []); print("No execution_label data found") if not buckets else print("Found {} unique execution label(s):\n".format(len(buckets))) or [print("  (not set): {} documents".format(b["doc_count"])) if b["key"] == "__NULL__" else print("  \"{}\": {} documents".format(b["key"], b["doc_count"])) for b in buckets]'

es-delete-index: es-check
	@$(SOURCE_ES_CONFIG); \
	SAFE_URL=$$(echo "$$ES_URL" | $(SANITIZE_URL)); \
	echo "==========================================" ;\
	echo "  WARNING: Delete Index" ;\
	echo "==========================================" ;\
	echo "" ;\
	echo "This will DELETE the entire index: $(ES_INDEX)" ;\
	echo "URL: $$SAFE_URL" ;\
	echo "" ;\
	read -p "Are you sure? Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ] || (echo "Cancelled."; exit 1); \
	echo "" ;\
	echo "Checking if $(ES_INDEX) is an alias or concrete index..." ;\
	ALIAS_CHECK=$$(curl -s "$${ES_URL}/_cat/aliases/$(ES_INDEX)" | head -n 1 | awk '{print $$2}'); \
	if [ -n "$$ALIAS_CHECK" ]; then \
		echo "$(ES_INDEX) is an alias pointing to: $$ALIAS_CHECK" ;\
		echo "Deleting concrete index: $$ALIAS_CHECK" ;\
		curl -X DELETE "$${ES_URL}/$$ALIAS_CHECK" | $(PYTHON) -m json.tool; \
	else \
		echo "$(ES_INDEX) is a concrete index" ;\
		echo "Deleting index..." ;\
		curl -X DELETE "$${ES_URL}/$(ES_INDEX)" | $(PYTHON) -m json.tool; \
	fi; \
	echo "" ;\
	echo "✓ Index $(ES_INDEX) deleted. Template will be applied on next upload."

# =============================================================================
# Index Lifecycle Management (ILM) Targets
# =============================================================================

es-ilm-policy: es-check
	@$(SOURCE_ES_CONFIG); \
	SAFE_URL=$$(echo "$$ES_URL" | $(SANITIZE_URL)); \
	echo "Detecting platform and applying lifecycle policy..."; \
	PLATFORM_VARS=$$(export ES_URL="$${ES_URL}"; bash $(ES_INTEGRATION_DIR)/detect_platform.sh 2>&1); \
	if [ $$? -ne 0 ]; then \
		echo "ERROR: Failed to detect platform"; \
		echo "$$PLATFORM_VARS"; \
		exit 1; \
	fi; \
	eval "$$PLATFORM_VARS"; \
	echo "Detected platform: $$PLATFORM (version $$VERSION)"; \
	echo "Applying policy: $$POLICY_NAME"; \
	echo ""; \
	curl -X PUT "$${ES_URL}$${POLICY_ENDPOINT}/$${POLICY_NAME}" \
		-H 'Content-Type: application/json' \
		-d @$(ES_INTEGRATION_DIR)/$${POLICY_FILE} | $(PYTHON) -m json.tool; \
	echo ""; \
	echo "✓ Lifecycle policy applied successfully"; \
	echo "  Platform: $$PLATFORM"; \
	echo "  Policy: $$POLICY_NAME"; \
	echo "  Phases: hot (30d) -> warm (7d) -> cold (30d) -> delete (90d)"

es-ilm-policy-no-delete: es-check
	@$(SOURCE_ES_CONFIG); \
	SAFE_URL=$$(echo "$$ES_URL" | $(SANITIZE_URL)); \
	echo "Detecting platform and applying lifecycle policy (NO DELETION)..."; \
	PLATFORM_VARS=$$(export ES_URL="$${ES_URL}"; bash $(ES_INTEGRATION_DIR)/detect_platform.sh 2>&1); \
	if [ $$? -ne 0 ]; then \
		echo "ERROR: Failed to detect platform"; \
		echo "$$PLATFORM_VARS"; \
		exit 1; \
	fi; \
	eval "$$PLATFORM_VARS"; \
	echo "Detected platform: $$PLATFORM (version $$VERSION)"; \
	echo "Applying policy: $$POLICY_NAME"; \
	echo ""; \
	if [ "$$PLATFORM" = "opensearch" ]; then \
		POLICY_FILE_NO_DELETE="opensearch_ism_policy_no_delete.json"; \
	else \
		echo "ERROR: No-delete policy currently only available for OpenSearch"; \
		echo "For ElasticSearch, manually edit es_ilm_policy.json to remove delete phase"; \
		exit 1; \
	fi; \
	curl -X PUT "$${ES_URL}$${POLICY_ENDPOINT}/$${POLICY_NAME}" \
		-H 'Content-Type: application/json' \
		-d @$(ES_INTEGRATION_DIR)/$${POLICY_FILE_NO_DELETE} | $(PYTHON) -m json.tool; \
	echo ""; \
	echo "✓ Lifecycle policy applied successfully (NO DELETION)"; \
	echo "  Platform: $$PLATFORM"; \
	echo "  Policy: $$POLICY_NAME"; \
	echo "  Phases: hot (30d) -> warm (7d) -> cold (30d)"; \
	echo "  NOTE: No delete phase - data retained permanently for CCR"

es-ilm-info: es-check
	@$(SOURCE_ES_CONFIG); \
	SAFE_URL=$$(echo "$$ES_URL" | $(SANITIZE_URL)); \
	echo "=========================================="; \
	echo "  Lifecycle Policy Information"; \
	echo "=========================================="; \
	echo ""; \
	PLATFORM_VARS=$$(export ES_URL="$${ES_URL}"; bash $(ES_INTEGRATION_DIR)/detect_platform.sh 2>&1); \
	eval "$$PLATFORM_VARS"; \
	echo "Platform: $$PLATFORM (version $$VERSION)"; \
	echo "Policy: $$POLICY_NAME"; \
	echo "URL: $$SAFE_URL"; \
	echo ""; \
	curl -s "$${ES_URL}$${POLICY_ENDPOINT}/$${POLICY_NAME}" | $(PYTHON) -m json.tool 2>/dev/null || echo "Policy does not exist. Run 'make es-ilm-policy' to create it."

es-ilm-explain: es-check
	@$(SOURCE_ES_CONFIG); \
	SAFE_URL=$$(echo "$$ES_URL" | $(SANITIZE_URL)); \
	echo "=========================================="; \
	echo "  Lifecycle Phase Explanation for Index"; \
	echo "=========================================="; \
	echo ""; \
	PLATFORM_VARS=$$(export ES_URL="$${ES_URL}"; bash $(ES_INTEGRATION_DIR)/detect_platform.sh 2>&1); \
	eval "$$PLATFORM_VARS"; \
	echo "Platform: $$PLATFORM"; \
	echo "Index: $(ES_INDEX)"; \
	echo "URL: $$SAFE_URL"; \
	echo ""; \
	curl -s "$${ES_URL}$${POLICY_EXPLAIN_PREFIX}$(ES_INDEX)$${POLICY_EXPLAIN_SUFFIX}" | $(PYTHON) -m json.tool 2>/dev/null || echo "Index does not exist or lifecycle management not enabled yet"

es-bootstrap-index: es-check es-ilm-policy-no-delete es-template
	@$(SOURCE_ES_CONFIG); \
	SAFE_URL=$$(echo "$$ES_URL" | $(SANITIZE_URL)); \
	echo "=========================================="; \
	echo "  Bootstrapping Rollover Index"; \
	echo "=========================================="; \
	echo ""; \
	PLATFORM_VARS=$$(export ES_URL="$${ES_URL}"; bash $(ES_INTEGRATION_DIR)/detect_platform.sh 2>&1); \
	eval "$$PLATFORM_VARS"; \
	echo "Platform: $$PLATFORM"; \
	echo "Creating initial write index: $(BASE_NAME)-000001"; \
	echo "Write alias: $(ES_WRITE_ALIAS)"; \
	echo "URL: $$SAFE_URL"; \
	echo ""; \
	curl -X PUT "$${ES_URL}/$(BASE_NAME)-000001" \
		-H 'Content-Type: application/json' \
		-d '{"aliases": {"$(ES_WRITE_ALIAS)": {"is_write_index": true}}, "settings": {"index.plugins.index_state_management.rollover_alias": "$(ES_WRITE_ALIAS)"}}' | $(PYTHON) -m json.tool; \
	echo ""; \
	echo "✓ Bootstrapped index created successfully"; \
	echo "  Write index: $(BASE_NAME)-000001"; \
	echo "  Write alias: $(ES_WRITE_ALIAS)"; \
	echo ""; \
	echo "NOTE: Upload to '$(ES_WRITE_ALIAS)' alias, not directly to $(BASE_NAME)-000001"

# =============================================================================
# Advanced Targets
# =============================================================================

# Clean build artifacts
clean:
	@echo "Cleaning temporary files..."
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@rm -rf $(GENERATED_DIR)/*
	@echo "✓ Report artifacts cleaned from REPORT/generated/"
