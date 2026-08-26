# Orion Regulus Makefile
# Organized into: Production targets (both prod and test) and Test-only targets

.PHONY: help

# Configuration
REG_ROOT ?= $(shell cd .. && pwd)
ES_INDEX ?= regulus-results-*
TEST_INDEX ?= regulus-mock-results
LOOKBACK ?= 15
IGNORE ?= rcos kernel
ORION_TAG ?= latest

# Helper to sanitize ES_URL for display (removes credentials)
SANITIZE_URL = sed -E 's|(https?://)([^:]+):([^@]+)@|\1***:***@|'

# Validate a Make variable contains only safe characters (alphanumeric, dots, hyphens, underscores, equals, spaces)
# Usage: @$(call VALIDATE_INPUT,VAR_NAME,$(VAR_VALUE))
define VALIDATE_INPUT
	@if [ -n '$(2)' ]; then \
		echo '$(2)' | grep -qE "^[a-zA-Z0-9 _.=-]+$$" || \
		{ echo "❌ Error: Invalid $(1) (allowed: alphanumeric, spaces, dots, hyphens, underscores, equals)"; exit 1; }; \
	fi
endef

# Helper to determine ES_URL with priority: env > lab.config
# Usage: @$(SOURCE_ES_CONFIG); your_command_using_$$ES_URL
SOURCE_ES_CONFIG = \
	if [ -n "$${ES_URL:-}" ]; then \
		export ES_URL; \
	elif [ -f "$(REG_ROOT)/lab.config" ]; then \
		. $(REG_ROOT)/lab.config; \
		if [ -z "$${ES_URL:-}" ]; then \
			if [ -z "$${ES_PROTOCOL:-}" ] || [ -z "$${ES_HOST:-}" ]; then \
				echo "ERROR: lab.config must define ES_URL or (ES_PROTOCOL + ES_HOST)"; \
				exit 1; \
			fi; \
			if [ -n "$${ES_USER:-}" ] && [ -n "$${ES_PASSWORD:-}" ]; then \
				ES_URL=$$(ES_USER="$${ES_USER}" ES_PASSWORD="$${ES_PASSWORD}" ES_HOST="$${ES_HOST}" ES_PROTOCOL="$${ES_PROTOCOL}" python3 -c "import os, urllib.parse; print(os.environ['ES_PROTOCOL'] + '://' + urllib.parse.quote(urllib.parse.unquote(os.environ['ES_USER']), safe='') + ':' + urllib.parse.quote(urllib.parse.unquote(os.environ['ES_PASSWORD']), safe='') + '@' + os.environ['ES_HOST'])"); \
			else \
				ES_URL="$${ES_PROTOCOL}://$${ES_HOST}"; \
			fi; \
		fi; \
		export ES_URL; \
	else \
		echo "ERROR: No ES configuration found."; \
		echo "  - No ES_URL environment variable"; \
		echo "  - No $(REG_ROOT)/lab.config file"; \
		exit 1; \
	fi

# ════════════════════════════════════════════════════════════════════════════════
# HELP
# ════════════════════════════════════════════════════════════════════════════════

help:
	@echo "════════════════════════════════════════════════════════════════════════════════"
	@echo "Orion Regulus Makefile Targets"
	@echo "════════════════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "═══ PRODUCTION TARGETS (work with both production and test data) ═══"
	@echo ""
	@echo "Setup:"
	@echo "  make setup"
	@echo "      Install orion + python dependencies (requires Python 3.11+)"
	@echo ""
	@echo "Discovery:"
	@echo "  make list-batches [ES_INDEX=index-pattern]"
	@echo "      List available batch IDs in Elasticsearch index"
	@echo ""
	@echo "  make show-mapping [ES_INDEX=index-pattern]"
	@echo "      Show raw ES index mapping (JSON)"
	@echo ""
	@echo "  make verify-mapping [ES_INDEX=index-pattern]"
	@echo "      Verify index mapping (iteration_id.keyword, batch_id, etc.)"
	@echo ""
	@echo "  make verify-batch BATCH_ID=batch-id [ES_INDEX=index-pattern]"
	@echo "      Verify batch data quality (all required fields present)"
	@echo ""
	@echo "Analysis:"
	@echo "  make analyze"
	@echo "      Auto-discover and analyze latest batch"
	@echo ""
	@echo "  make analyze BATCH_ID=test-batch-2026-07-08"
	@echo "      Analyze specific batch (auto-discovers all fingerprints)"
	@echo ""
	@echo "  make analyze BATCH_ID=test-batch-2026-07-08 IGNORE='rcos'"
	@echo "      Cross-version analysis (ignore rcos field from fingerprint)"
	@echo ""
	@echo "  make analyze BATCH_ID=test-batch-2026-07-08 MATCH='threads=128'"
	@echo "      Filter to specific tests within batch"
	@echo ""
	@echo "  make analyze BATCH_ID=test-batch-2026-07-08 MATCH='threads=128' IGNORE='kernel rcos'"
	@echo "      Combine MATCH filter and IGNORE grouping"
	@echo ""
	@echo "  make analyze USE_LOCAL=1"
	@echo "      Use pip-installed orion CLI instead of podman (warns if outdated)"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean"
	@echo "      Clean generated configs and Orion outputs"
	@echo ""
	@echo "  make clean-mock"
	@echo "      Clean mock batches from ES + local generated/backup files"
	@echo ""
	@echo "═══ TEST-ONLY TARGETS (mock data generation and testing) ═══"
	@echo ""
	@echo "  make create-mock"
	@echo "      Generate mock test data (3 fingerprints: stable, regression, improvement)"
	@echo ""
	@echo "  make push-batch [TEST_INDEX=regulus-mock-results]"
	@echo "      Push generated mock data to Elasticsearch"
	@echo ""
	@echo "  make pull-batch BATCH_ID=test-batch-001 [TEST_INDEX=regulus-mock-results]"
	@echo "      Pull specific batch from Elasticsearch to local file"
	@echo ""
	@echo "  make test-full"
	@echo "      Full test cycle: create mock → push → analyze → verify (auto PASS/FAIL)"
	@echo ""
	@echo "  make verify-test"
	@echo "      Validate results from last analysis (check for PASS/FAIL)"
	@echo ""
	@echo "  make test-prow"
	@echo "      Test Prow entry point locally (simulates Prow CI environment)"
	@echo ""
	@echo "════════════════════════════════════════════════════════════════════════════════"
	@echo "Current Configuration:"
	@$(SOURCE_ES_CONFIG) 2>/dev/null && echo "  ES_URL     = $$(echo "$$ES_URL" | $(SANITIZE_URL))" || echo "  ES_URL     = (not configured)"
	@echo "  ES_INDEX   = $(ES_INDEX)"
	@echo "  TEST_INDEX = $(TEST_INDEX)"
	@echo "  LOOKBACK   = $(LOOKBACK)"
	@echo "  ORION_TAG  = $(ORION_TAG)"
	@echo "════════════════════════════════════════════════════════════════════════════════"

# ════════════════════════════════════════════════════════════════════════════════
# SETUP
# ════════════════════════════════════════════════════════════════════════════════

.PHONY: setup
setup: ## Install orion + python dependencies (requires Python 3.11+)
	@PIP=pip3.11; \
	if ! command -v $$PIP >/dev/null 2>&1; then PIP=pip3; fi; \
	echo "📦 Installing Python dependencies (using $$PIP)..."; \
	$$PIP install -q -r requirements.txt; \
	ORION_TAG='$(ORION_TAG)'; \
	if [ "$$ORION_TAG" = "latest" ]; then \
		$$PIP install -q orion@git+https://github.com/cloud-bulldozer/orion.git; \
	else \
		$$PIP install -q "orion@git+https://github.com/cloud-bulldozer/orion.git@$$ORION_TAG"; \
	fi; \
	echo "✅ Setup complete (orion $$ORION_TAG)"

# ════════════════════════════════════════════════════════════════════════════════
# PRODUCTION TARGETS (applicable to both production and test environments)
# ════════════════════════════════════════════════════════════════════════════════

# List available batches
.PHONY: list-batches
list-batches:
	@echo "📋 Listing batches in $(ES_INDEX)..."
	@$(SOURCE_ES_CONFIG); curl -s "$$ES_URL/$(ES_INDEX)/_search" -H 'Content-Type: application/json' \
		-d '{"size":0,"aggs":{"batches":{"terms":{"field":"batch_id.keyword","size":50,"order":{"latest":"desc"}},"aggs":{"latest":{"max":{"field":"@timestamp"}},"count":{"value_count":{"field":"iteration_id.keyword"}},"upload_time":{"max":{"field":"uploaded_at"}}}}}}' \
		| ./scripts/list-batches.py

# Show raw index mapping
.PHONY: show-mapping
show-mapping:
	@$(SOURCE_ES_CONFIG); curl -s "$$ES_URL/$(ES_INDEX)/_mapping" | python3 -m json.tool

# Verify index mapping compatibility
.PHONY: verify-mapping
verify-mapping:
	@echo "🔍 Verifying mapping compatibility for $(ES_INDEX)..."
	@echo ""
	@$(SOURCE_ES_CONFIG); curl -s "$$ES_URL/$(ES_INDEX)/_mapping" | ./scripts/verify-mapping.py

# Verify batch data quality
.PHONY: verify-batch
verify-batch:
	@if [ -z '$(BATCH_ID)' ]; then \
		echo "❌ Error: BATCH_ID required"; \
		echo "Usage: make verify-batch BATCH_ID=test-batch-001"; \
		exit 1; \
	fi
	@echo '$(BATCH_ID)' | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9._-]*$$' || { echo "❌ Error: Invalid BATCH_ID (must start with alphanumeric; allowed: alphanumeric, dots, hyphens, underscores)"; exit 1; }
	@echo "🔍 Verifying batch data quality: $(BATCH_ID)"
	@echo "   Index: $(ES_INDEX)"
	@echo ""
	@$(SOURCE_ES_CONFIG); BATCH_ID='$(BATCH_ID)' python3 -c \
		'import os,json;print(json.dumps({"query":{"term":{"batch_id.keyword":os.environ["BATCH_ID"]}},"size":100}))' \
		| curl -s "$$ES_URL/$(ES_INDEX)/_search" -H 'Content-Type: application/json' -d @- \
		| ./scripts/verify-batch.py

# Run Orion analysis
.PHONY: analyze
analyze:
	$(call VALIDATE_INPUT,BATCH_ID,$(BATCH_ID))
	$(call VALIDATE_INPUT,MATCH,$(MATCH))
	$(call VALIDATE_INPUT,IGNORE,$(IGNORE))
	$(call VALIDATE_INPUT,LOOKBACK,$(LOOKBACK))
	@$(SOURCE_ES_CONFIG); ./scripts/analyze-batch.py \
		$(if $(BATCH_ID),--batch-id '$(BATCH_ID)') \
		$(if $(MATCH),--match '$(MATCH)') \
		$(if $(IGNORE),--ignore '$(IGNORE)') \
		--es-server "$$ES_URL" \
		--es-index '$(ES_INDEX)' \
		--lookback '$(LOOKBACK)' \
		$(if $(DEBUG),--debug) \
		$(if $(SELF_DETECT),--use-self-detect) \
		$(if $(USE_LOCAL),--use-local-cli)

# Clean generated files
.PHONY: clean
clean:
	@echo "🧹 Cleaning generated files..."
	@rm -rf generated-configs/*
	@rm -rf generated-orion/*
	@echo "✅ Clean complete"

# Clean mock data from Elasticsearch and local files
.PHONY: clean-mock
clean-mock:
	@echo "🧹 Cleaning mock data..."
	@echo ""
	@echo "1️⃣ Deleting mock batches from Elasticsearch ($(TEST_INDEX))..."
	@$(SOURCE_ES_CONFIG); curl -X POST "$$ES_URL/$(TEST_INDEX)/_delete_by_query" \
		-H 'Content-Type: application/json' \
		-d '{"query":{"bool":{"should":[{"prefix":{"batch_id.keyword":"test-batch-"}},{"prefix":{"batch_id.keyword":"historical-"}}]}}}' \
		-s | python3 -c "import sys, json; data = json.load(sys.stdin); deleted = data.get('deleted', 0); print(f'   ✓ Deleted {deleted} document(s) from ES')"
	@sleep 1
	@echo ""
	@echo "2️⃣ Cleaning local generated mock files..."
	@rm -rf unit-test/generated/*
	@echo "   ✓ Deleted unit-test/generated/*"
	@echo ""
	@echo "3️⃣ Cleaning backup files..."
	@rm -rf unit-test/backup/*
	@echo "   ✓ Deleted unit-test/backup/*"
	@echo ""
	@echo "✅ Mock cleanup complete"
	@echo ""
	@$(SOURCE_ES_CONFIG); curl -s "$$ES_URL/$(TEST_INDEX)/_count" | \
		python3 -c "import sys, json; print('   Documents remaining in $(TEST_INDEX):', json.load(sys.stdin)['count'])"

# ════════════════════════════════════════════════════════════════════════════════
# TEST-ONLY TARGETS (mock data generation and testing)
# ════════════════════════════════════════════════════════════════════════════════

# Create mock test data
.PHONY: create-mock
create-mock:
	@echo "🔧 Generating mock test data..."
	@cd unit-test && ./generate-batch-test-data.py \
		--batch-id "test-batch-$$(date +%Y-%m-%d)" \
		--output generated/batch-mocked-data.json \
		--historical-samples 20
	@echo "✅ Generated: unit-test/generated/batch-mocked-data.json"
	@jq 'length' unit-test/generated/batch-mocked-data.json | xargs -I {} echo "   Documents: {}"

# Push mock data to Elasticsearch
.PHONY: push-batch
push-batch:
	@if [ ! -f "unit-test/generated/batch-mocked-data.json" ]; then \
		echo "❌ Error: Mock data not found. Run 'make create-mock' first"; \
		exit 1; \
	fi
	@echo "📤 Pushing mock data to $(TEST_INDEX)..."
	@cd unit-test && ./json-to-bulk.py \
		generated/batch-mocked-data.json \
		generated/batch-mocked-data.ndjson \
		--index $(TEST_INDEX)
	@$(SOURCE_ES_CONFIG); curl -X POST "$$ES_URL/_bulk" \
		-H 'Content-Type: application/x-ndjson' \
		--data-binary '@unit-test/generated/batch-mocked-data.ndjson' \
		-s | python3 -c "import sys, json; data = json.load(sys.stdin); print('❌ Errors occurred during indexing') if data.get('errors') else print('✅ Successfully pushed to $(TEST_INDEX)'); sys.exit(1) if data.get('errors') else sys.exit(0)"
	@sleep 1
	@$(SOURCE_ES_CONFIG); curl -s "$$ES_URL/$(TEST_INDEX)/_count" | \
		python3 -c "import sys, json; print('   Documents in index:', json.load(sys.stdin)['count'])"

# Pull batch from Elasticsearch
.PHONY: pull-batch
pull-batch:
	@if [ -z '$(BATCH_ID)' ]; then \
		echo "❌ Error: BATCH_ID required"; \
		echo "Usage: make pull-batch BATCH_ID=test-batch-001"; \
		exit 1; \
	fi
	@echo '$(BATCH_ID)' | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9._-]*$$' || { echo "❌ Error: Invalid BATCH_ID (must start with alphanumeric; allowed: alphanumeric, dots, hyphens, underscores)"; exit 1; }
	@echo "📥 Pulling batch $(BATCH_ID) from $(TEST_INDEX)..."
	@mkdir -p unit-test/backup
	@$(SOURCE_ES_CONFIG); cd unit-test && BATCH_ID='$(BATCH_ID)' \
		QUERY=$$(python3 -c 'import os,json;print(json.dumps({"match":{"batch_id":os.environ["BATCH_ID"]}}))') && \
		./pull-from-opensearch.py \
		--es-server "$$ES_URL" \
		--index '$(TEST_INDEX)' \
		--query "$$QUERY" \
		--output 'backup/pulled-batch-$(BATCH_ID).json'
	@echo "✅ Pulled to: unit-test/backup/pulled-batch-$(BATCH_ID).json"
	@jq 'length' 'unit-test/backup/pulled-batch-$(BATCH_ID).json' | xargs -I {} echo "   Documents: {}"

# Full test cycle
.PHONY: test-full
test-full: setup clean create-mock push-batch
	@echo ""
	@echo "════════════════════════════════════════════════════════════════════════════════"
	@echo "🧪 Running Full Test Cycle"
	@echo "════════════════════════════════════════════════════════════════════════════════"
	@echo ""
	@$(SOURCE_ES_CONFIG); \
	BATCH_ID=$$(jq -r '[.[] | select(.batch_id | startswith("test-batch-"))] | .[0].batch_id' unit-test/generated/batch-mocked-data.json); \
	echo "📊 Analyzing batch: $$BATCH_ID"; \
	./scripts/analyze-batch.py \
		--batch-id "$$BATCH_ID" \
		--es-server "$$ES_URL" \
		--es-index "$(TEST_INDEX)" \
		--lookback "$(LOOKBACK)" \
		> /tmp/test-results.txt 2>&1; \
	TEST_EXIT=$$?; \
	cat /tmp/test-results.txt
	@./scripts/validate-test-results.sh /tmp/test-results.txt

# Verify test results (standalone validation)
.PHONY: verify-test
verify-test:
	@./scripts/validate-test-results.sh /tmp/test-results.txt

# Test Prow entry point locally (simulates Prow environment)
.PHONY: test-prow
test-prow: setup
	@echo ""
	@echo "════════════════════════════════════════════════════════════════════════════════"
	@echo "🧪 Testing Prow Entry Point (local simulation)"
	@echo "════════════════════════════════════════════════════════════════════════════════"
	@echo ""
	@$(SOURCE_ES_CONFIG); \
	BATCH_ID=$$(jq -r '[.[] | select(.batch_id | startswith("test-batch-"))] | .[0].batch_id' unit-test/generated/batch-mocked-data.json 2>/dev/null || echo ""); \
	if [ -z "$$BATCH_ID" ]; then \
		echo "⚠️  No mock data found. Run 'make create-mock && make push-batch' first."; \
		exit 1; \
	fi; \
	echo "Simulating Prow env vars:"; \
	echo "  ES_URL          = $$(echo "$$ES_URL" | $(SANITIZE_URL))"; \
	echo "  ES_BENCHMARK_INDEX = $(TEST_INDEX)"; \
	echo "  BATCH_ID           = $$BATCH_ID"; \
	echo "  LOOKBACK           = $(LOOKBACK)"; \
	echo "  ARTIFACT_DIR       = /tmp/prow-artifacts"; \
	echo ""; \
	mkdir -p /tmp/prow-artifacts; \
	ES_URL="$$ES_URL" \
	ES_BENCHMARK_INDEX="$(TEST_INDEX)" \
	BATCH_ID="$$BATCH_ID" \
	MATCH="" \
	IGNORE="" \
	LOOKBACK="$(LOOKBACK)" \
	DEBUG="false" \
	ARTIFACT_DIR="/tmp/prow-artifacts" \
	./scripts/prow-entry.sh; \
	PROW_EXIT=$$?; \
	echo ""; \
	echo "Artifacts in /tmp/prow-artifacts/:"; \
	ls -1 /tmp/prow-artifacts/ 2>/dev/null; \
	exit $$PROW_EXIT
