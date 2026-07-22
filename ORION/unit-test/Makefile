# Makefile for Orion Regulus Unit Test / Mock Data Operations
#
# Usage:
#   make help           - Show available targets
#   make generate       - Generate mock data
#   make convert        - Convert to bulk format
#   make index          - Index to OpenSearch
#   make pull           - Pull from OpenSearch
#   make test           - Run Orion tests
#   make clean          - Clean generated files
#   make full-cycle     - Complete workflow
#
# Environment Variables:
#   ES_SERVER           - OpenSearch server URL (default: http://localhost:9200)
#   ORION_DIR           - Path to Orion directory (required for testing)
#   ES_USER             - OpenSearch username (optional)
#   ES_PASSWORD         - OpenSearch password (optional)

# Configuration
ES_SERVER ?= http://localhost:9200
ES_INDEX ?= regulus-results-mock
ORION_DIR ?= ../../orion

# Files and directories
GENERATED_DIR = generated
SCENARIOS_FILE = $(GENERATED_DIR)/mock-data.json
BULK_FILE = $(GENERATED_DIR)/bulk-all.ndjson
PULLED_DIR = $(GENERATED_DIR)/pulled
PULLED_FILE = $(PULLED_DIR)/all-pulled-data.json

# Colors for output (shell variables for echo -e)
RED := $(shell echo -e "\033[0;31m")
GREEN := $(shell echo -e "\033[0;32m")
YELLOW := $(shell echo -e "\033[1;33m")
BLUE := $(shell echo -e "\033[0;34m")
NC := $(shell echo -e "\033[0m")

# Default target
.DEFAULT_GOAL := help

##@ General

.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)  ORION REGULUS UNIT TEST - MAKEFILE TARGETS$(NC)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "$(GREEN)Usage:$(NC) make $(YELLOW)<target>$(NC)\n\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(GREEN)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Environment Variables:$(NC)"
	@echo "  ES_SERVER    = $(ES_SERVER)"
	@echo "  ES_INDEX     = $(ES_INDEX)"
	@echo "  ORION_DIR    = $(ORION_DIR)"
	@echo ""
	@echo "$(GREEN)Override with:$(NC) make target ES_SERVER=http://your-server:9200"
	@echo ""

##@ Step 1: Generate Mock Data

.PHONY: generate
generate: ## Generate all mock data scenarios (240 docs)
	@echo "$(GREEN)[1/6] Generating mock data...$(NC)"
	./generate-mock-data.py --scenario all --output $(SCENARIOS_FILE)
	@echo "$(GREEN)✓ Generated: $(SCENARIOS_FILE)$(NC)"
	@jq 'length' $(SCENARIOS_FILE) | xargs -I {} echo "  Documents: {}"

.PHONY: generate-regression
generate-regression: ## Generate only regression scenario (30 docs)
	@echo "$(GREEN)Generating regression scenario...$(NC)"
	./generate-mock-data.py --scenario regression --output $(GENERATED_DIR)/regression.json
	@echo "$(GREEN)✓ Generated: $(GENERATED_DIR)/regression.json$(NC)"

.PHONY: generate-gradual
generate-gradual: ## Generate only gradual degradation (40 docs)
	@echo "$(GREEN)Generating gradual degradation scenario...$(NC)"
	./generate-mock-data.py --scenario gradual --output $(GENERATED_DIR)/gradual.json
	@echo "$(GREEN)✓ Generated: $(GENERATED_DIR)/gradual.json$(NC)"

.PHONY: generate-all-separate
generate-all-separate: ## Generate each scenario to separate files
	@echo "$(GREEN)Generating all scenarios separately...$(NC)"
	./generate-mock-data.py --scenario stable --output $(GENERATED_DIR)/01-stable.json
	./generate-mock-data.py --scenario regression --output $(GENERATED_DIR)/02-regression.json
	./generate-mock-data.py --scenario gradual --output $(GENERATED_DIR)/03-gradual.json
	./generate-mock-data.py --scenario improvement --output $(GENERATED_DIR)/04-improvement.json
	./generate-mock-data.py --scenario intermittent --output $(GENERATED_DIR)/05-intermittent.json
	./generate-mock-data.py --scenario multi-metric --output $(GENERATED_DIR)/06-multimetric.json
	@echo "$(GREEN)✓ Generated 6 separate scenario files$(NC)"

##@ Step 2: Convert to Bulk Format

.PHONY: convert
convert: $(SCENARIOS_FILE) ## Convert JSON to NDJSON bulk format
	@echo "$(GREEN)[2/6] Converting to bulk format...$(NC)"
	./json-to-bulk.py $(SCENARIOS_FILE) $(BULK_FILE)
	@echo "$(GREEN)✓ Converted: $(BULK_FILE)$(NC)"
	@wc -l $(BULK_FILE) | awk '{print "  Lines:", $$1, "(should be 480: 240 actions + 240 docs)"}'

.PHONY: convert-all
convert-all: generate-all-separate ## Convert all separate scenario files to bulk
	@echo "$(GREEN)Converting all scenarios to bulk format...$(NC)"
	@for file in $(GENERATED_DIR)/*.json; do \
		base=$$(basename $$file .json); \
		./json-to-bulk.py $$file $(GENERATED_DIR)/$$base.ndjson; \
	done
	@echo "$(GREEN)✓ Converted all scenario files to NDJSON$(NC)"

##@ Step 3: Index to OpenSearch

.PHONY: create-index
create-index: ## Create index with correct mapping (iteration_id.keyword)
	@echo "$(GREEN)Creating index with correct mapping...$(NC)"
	@echo "  Server: $(ES_SERVER)"
	@echo "  Index:  $(ES_INDEX)"
	@curl -X PUT "$(ES_SERVER)/$(ES_INDEX)" \
		-H 'Content-Type: application/json' \
		-d @aws-index-mapping.json \
		-s | jq -r 'if .acknowledged then "$(GREEN)✓ Index created with correct mapping$(NC)" else "$(RED)✗ Failed to create index$(NC)" end'
	@echo "$(GREEN)Verifying mapping...$(NC)"
	@curl -s "$(ES_SERVER)/$(ES_INDEX)/_mapping" | \
		python3 -c "import sys, json; m=json.load(sys.stdin); print('  iteration_id mapping:', json.dumps(m['$(ES_INDEX)']['mappings']['properties'].get('iteration_id', {}), indent=4))"

.PHONY: index
index: create-index $(BULK_FILE) ## Index bulk data to OpenSearch
	@echo "$(GREEN)[3/6] Indexing to OpenSearch...$(NC)"
	@echo "  Server: $(ES_SERVER)"
	@echo "  Index:  $(ES_INDEX)"
	@curl -X POST "$(ES_SERVER)/_bulk" \
		-H 'Content-Type: application/x-ndjson' \
		--data-binary '@$(BULK_FILE)' \
		-s | jq -r 'if .errors then "ERROR" else "SUCCESS" end' | \
		sed 's/ERROR/$(RED)✗ Errors occurred$(NC)/; s/SUCCESS/$(GREEN)✓ Indexed successfully$(NC)/'
	@sleep 1
	@$(MAKE) -s verify-index

.PHONY: index-direct
index-direct: create-index ## Generate and index directly (no local files)
	@echo "$(GREEN)Generating and indexing directly to OpenSearch...$(NC)"
	./generate-mock-data.py --scenario all \
		--index-to-opensearch \
		--es-server $(ES_SERVER) \
		--es-index $(ES_INDEX)
	@sleep 1
	@$(MAKE) -s verify-index

.PHONY: verify-index
verify-index: ## Verify documents in OpenSearch
	@echo "$(GREEN)Verifying index...$(NC)"
	@curl -s "$(ES_SERVER)/$(ES_INDEX)/_count" | jq -r '"  Documents in index: " + (.count | tostring)'

##@ Step 4: Pull from OpenSearch

.PHONY: pull
pull: ## Pull data from OpenSearch to local files
	@echo "$(GREEN)[4/6] Pulling from OpenSearch...$(NC)"
	./pull-from-opensearch.py --es-server $(ES_SERVER) --index "$(ES_INDEX)*"
	@echo "$(GREEN)✓ Pulled: $(PULLED_FILE)$(NC)"
	@jq 'length' $(PULLED_FILE) | xargs -I {} echo "  Documents pulled: {}"

.PHONY: pull-regression
pull-regression: ## Pull only regression test data (nic=mlx5_0)
	@echo "$(GREEN)Pulling regression test data...$(NC)"
	./pull-from-opensearch.py \
		--es-server $(ES_SERVER) \
		--index "$(ES_INDEX)*" \
		--query '{"term": {"nic": "mlx5_0"}}' \
		--output $(GENERATED_DIR)/pulled-regression

.PHONY: pull-with-auth
pull-with-auth: ## Pull with authentication (set ES_USER and ES_PASSWORD)
	@echo "$(GREEN)Pulling with authentication...$(NC)"
	./pull-from-opensearch.py \
		--es-server $(ES_SERVER) \
		--index "$(ES_INDEX)*" \
		--es-user $(ES_USER) \
		--es-password $(ES_PASSWORD)

##@ Step 5: Re-Index

.PHONY: reindex
reindex: $(PULLED_FILE) ## Re-index pulled data to practice index
	@echo "$(GREEN)[5/6] Re-indexing pulled data...$(NC)"
	./json-to-bulk.py $(PULLED_FILE) $(PULLED_DIR)/bulk-reindex.ndjson --index $(ES_INDEX)-practice
	@curl -X POST "$(ES_SERVER)/_bulk" \
		-H 'Content-Type: application/x-ndjson' \
		--data-binary '@$(PULLED_DIR)/bulk-reindex.ndjson' \
		-s | jq -r 'if .errors then "ERROR" else "SUCCESS" end' | \
		sed 's/ERROR/$(RED)✗ Errors occurred$(NC)/; s/SUCCESS/$(GREEN)✓ Re-indexed to $(ES_INDEX)-practice$(NC)/'
	@sleep 1
	@curl -s "$(ES_SERVER)/$(ES_INDEX)-practice/_count" | jq -r '"  Documents: " + (.count | tostring)'

##@ Step 6: Test with Orion

.PHONY: test
test: ## Quick validation - Run Hunter on regression scenario (expect: 2 regressions detected)
	@echo "$(GREEN)[6/6] Running Orion regression test...$(NC)"
	@if [ ! -f "$(ORION_DIR)/run-it" ]; then \
		echo "$(RED)Error: Orion not found at $(ORION_DIR)$(NC)"; \
		echo "Set with: make test ORION_DIR=/path/to/your/orion"; \
		exit 1; \
	fi
	cd $(ORION_DIR) && ./run-it \
		--config ../orion-regulus-dev/configs/regulus-mock-regression.yaml \
		--hunter-analyze \
		--benchmark-index=$(ES_INDEX)* \
		--metadata-index=$(ES_INDEX)*

.PHONY: test-all
test-all: ## Full test suite - Run all 5 scenarios: stable, regression, gradual, improvement, intermittent
	@echo "$(GREEN)Running all Orion test scenarios...$(NC)"
	@if [ ! -f "$(ORION_DIR)/run-it" ]; then \
		echo "$(RED)Error: Orion not found at $(ORION_DIR)$(NC)"; \
		exit 1; \
	fi
	./test-mock-data.sh

.PHONY: test-gradual
test-gradual: ## Limitation test - Slow degradation (Hunter may not detect gradual changes)
	@echo "$(GREEN)Running Orion gradual degradation test...$(NC)"
	cd $(ORION_DIR) && ./run-it \
		--config ../orion-regulus-dev/configs/regulus-mock-gradual.yaml \
		--hunter-analyze \
		--benchmark-index=$(ES_INDEX)* \
		--metadata-index=$(ES_INDEX)*

.PHONY: test-intermittent
test-intermittent: ## Negative test - Temporary outliers (expect: NO regressions - correct behavior!)
	@echo "$(GREEN)Running Orion intermittent outliers test...$(NC)"
	cd $(ORION_DIR) && ./run-it \
		--config ../orion-regulus-dev/configs/regulus-mock-intermittent.yaml \
		--hunter-analyze \
		--benchmark-index=$(ES_INDEX)* \
		--metadata-index=$(ES_INDEX)*

.PHONY: compare-algorithms
compare-algorithms: ## Algorithm comparison - Run all 3 algorithms on same data (Hunter vs CMR vs Anomaly)
	@echo "$(BLUE)════════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)  ALGORITHM COMPARISON - Hunter vs CMR vs Anomaly Detection$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(GREEN)Testing on: regulus-mock-regression.yaml (200 samples with 2 regression points)$(NC)"
	@echo ""
	@echo "$(YELLOW)[1/3] Running HUNTER (EDivisive)...$(NC)"
	@cd $(ORION_DIR) && ./run-it \
		--config ../orion-regulus-dev/configs/regulus-mock-regression.yaml \
		--hunter-analyze \
		--benchmark-index=$(ES_INDEX)* \
		--metadata-index=$(ES_INDEX)* \
		> ../orion-regulus-dev/output/algorithm-comparison/hunter.txt 2>&1 || true
	@echo "$(GREEN)✓ Hunter complete$(NC)"
	@echo ""
	@echo "$(YELLOW)[2/3] Running CMR (Comparing Mean Responses)...$(NC)"
	@cd $(ORION_DIR) && ./run-it \
		--config ../orion-regulus-dev/configs/regulus-mock-regression.yaml \
		--cmr \
		--benchmark-index=$(ES_INDEX)* \
		--metadata-index=$(ES_INDEX)* \
		> ../orion-regulus-dev/output/algorithm-comparison/cmr.txt 2>&1 || true
	@echo "$(GREEN)✓ CMR complete$(NC)"
	@echo ""
	@echo "$(YELLOW)[3/3] Running ANOMALY DETECTION (IsolationForest)...$(NC)"
	@cd $(ORION_DIR) && ./run-it \
		--config ../orion-regulus-dev/configs/regulus-mock-regression.yaml \
		--anomaly-detection \
		--anomaly-window 5 \
		--min-anomaly-percent 10 \
		--benchmark-index=$(ES_INDEX)* \
		--metadata-index=$(ES_INDEX)* \
		> ../orion-regulus-dev/output/algorithm-comparison/anomaly.txt 2>&1 || true
	@echo "$(GREEN)✓ Anomaly Detection complete$(NC)"
	@echo ""
	@echo "$(BLUE)════════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)  RESULTS SUMMARY$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Hunter (EDivisive):$(NC)"
	@grep -A 6 "Changepoint at:" ../orion-regulus-dev/output/algorithm-comparison/hunter.txt | grep "throughput_regression" || echo "  No regressions detected"
	@echo ""
	@echo "$(YELLOW)CMR (Comparing Mean Responses):$(NC)"
	@grep -A 6 "Changepoint at:" ../orion-regulus-dev/output/algorithm-comparison/cmr.txt | grep "throughput_regression" || echo "  No regressions detected"
	@echo ""
	@echo "$(YELLOW)Anomaly Detection (IsolationForest):$(NC)"
	@grep -A 6 "Changepoint at:" ../orion-regulus-dev/output/algorithm-comparison/anomaly.txt | grep "throughput_regression" || echo "  No anomalies detected"
	@echo ""
	@echo "$(GREEN)Full results saved to:$(NC)"
	@echo "  - output/algorithm-comparison/hunter.txt"
	@echo "  - output/algorithm-comparison/cmr.txt"
	@echo "  - output/algorithm-comparison/anomaly.txt"
	@echo ""

##@ Complete Workflows

.PHONY: full-cycle
full-cycle: clean generate convert index verify-index ## Complete workflow: generate → convert → index → verify
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)✓ FULL CYCLE COMPLETE!$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "Next steps:"
	@echo "  make pull          - Pull data back from OpenSearch"
	@echo "  make test          - Run Orion tests"
	@echo "  make view          - View generated data"
	@echo ""

.PHONY: practice-cycle
practice-cycle: full-cycle pull ## Practice cycle: generate → index → pull
	@echo "$(GREEN)✓ Practice cycle complete! Data generated, indexed, and pulled back.$(NC)"

.PHONY: round-trip
round-trip: full-cycle pull reindex ## Full round trip: generate → index → pull → reindex
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)✓ ROUND TRIP COMPLETE!$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "Data has been:"
	@echo "  1. Generated locally"
	@echo "  2. Indexed to OpenSearch ($(ES_INDEX))"
	@echo "  3. Pulled back from OpenSearch"
	@echo "  4. Re-indexed to practice index ($(ES_INDEX)-practice)"
	@echo ""

##@ Inspection and Analysis

.PHONY: view
view: ## View first document from generated data
	@echo "$(GREEN)First document in generated data:$(NC)"
	@jq '.[0]' $(SCENARIOS_FILE) 2>/dev/null || echo "$(RED)No data generated yet. Run: make generate$(NC)"

.PHONY: view-pulled
view-pulled: ## View first document from pulled data
	@echo "$(GREEN)First document in pulled data:$(NC)"
	@jq '.[0]' $(PULLED_FILE) 2>/dev/null || echo "$(RED)No pulled data. Run: make pull$(NC)"

.PHONY: stats
stats: ## Show statistics about generated data
	@echo "$(GREEN)Generated Data Statistics:$(NC)"
	@if [ -f $(SCENARIOS_FILE) ]; then \
		jq '[.[] | .mean] | {min: min, max: max, avg: (add/length)}' $(SCENARIOS_FILE); \
	else \
		echo "$(RED)No data generated yet. Run: make generate$(NC)"; \
	fi

.PHONY: count
count: ## Count documents in all files
	@echo "$(GREEN)Document Counts:$(NC)"
	@if [ -f $(SCENARIOS_FILE) ]; then \
		echo "  Generated:  $$(jq 'length' $(SCENARIOS_FILE)) docs"; \
	fi
	@if [ -f $(PULLED_FILE) ]; then \
		echo "  Pulled:     $$(jq 'length' $(PULLED_FILE)) docs"; \
	fi

.PHONY: list-indices
list-indices: ## List all OpenSearch indices
	@echo "$(GREEN)OpenSearch Indices:$(NC)"
	@curl -s "$(ES_SERVER)/_cat/indices?v" | grep -E "(index|regulus)" || echo "No regulus indices found"

##@ Cleanup Operations

.PHONY: clean
clean: ## Clean generated files (keeps templates)
	@echo "$(YELLOW)Cleaning generated files...$(NC)"
	rm -rf $(GENERATED_DIR)
	@echo "$(GREEN)✓ Cleaned: $(GENERATED_DIR)/$(NC)"

.PHONY: clean-index
clean-index: ## Delete OpenSearch index
	@echo "$(YELLOW)Deleting OpenSearch index: $(ES_INDEX)$(NC)"
	@curl -X DELETE "$(ES_SERVER)/$(ES_INDEX)" -s | jq -r 'if .acknowledged then "DELETED" else "FAILED" end' | \
		sed 's/DELETED/$(GREEN)✓ Deleted$(NC)/; s/FAILED/$(RED)✗ Failed$(NC)/'

.PHONY: clean-all-indices
clean-all-indices: ## Delete all mock-related indices
	@echo "$(YELLOW)Deleting all mock-related indices...$(NC)"
	@curl -X DELETE "$(ES_SERVER)/$(ES_INDEX)" -s > /dev/null 2>&1 || true
	@curl -X DELETE "$(ES_SERVER)/$(ES_INDEX)-practice" -s > /dev/null 2>&1 || true
	@echo "$(GREEN)✓ Cleaned all mock indices$(NC)"

.PHONY: clean-all
clean-all: clean clean-all-indices ## Clean everything (files + indices)
	@echo "$(GREEN)✓ Everything cleaned!$(NC)"

.PHONY: reset
reset: clean-all ## Reset to clean slate (alias for clean-all)
	@echo "$(GREEN)✓ Reset complete. Ready for fresh start!$(NC)"

##@ Practice Exercises

.PHONY: exercise1
exercise1: clean generate view ## Exercise 1: Generate and inspect
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)Exercise 1 Complete: Generate and Inspect$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "You generated $(shell jq 'length' $(SCENARIOS_FILE)) documents"
	@echo ""
	@echo "Next: make exercise2"
	@echo ""

.PHONY: exercise2
exercise2: exercise1 convert index verify-index ## Exercise 2: Generate → Convert → Index
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)Exercise 2 Complete: Index to OpenSearch$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "Next: make exercise3"
	@echo ""

.PHONY: exercise3
exercise3: exercise2 pull view-pulled ## Exercise 3: Full cycle with pull
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)Exercise 3 Complete: Pull data back from OpenSearch$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "Compare documents:"
	@echo "  Generated: $(shell jq 'length' $(SCENARIOS_FILE))"
	@echo "  Pulled:    $(shell jq 'length' $(PULLED_FILE))"
	@echo ""
	@echo "All exercises complete! 🎉"
	@echo ""

##@ Utility Targets

.PHONY: check-env
check-env: ## Check environment variables
	@echo "$(GREEN)Environment Check:$(NC)"
	@echo "  ES_SERVER:   $(ES_SERVER)"
	@echo "  ES_INDEX:    $(ES_INDEX)"
	@echo "  ORION_DIR:   $(ORION_DIR)"
	@if [ "$(ORION_DIR)" = "/path/to/orion" ]; then \
		echo "  $(YELLOW)⚠ ORION_DIR not configured for testing$(NC)"; \
	else \
		echo "  $(GREEN)✓ ORION_DIR configured$(NC)"; \
	fi

.PHONY: show-files
show-files: ## Show all generated files
	@echo "$(GREEN)Generated Files:$(NC)"
	@ls -lh $(GENERATED_DIR) 2>/dev/null || echo "  No files generated yet"

# Ensure generated directory exists for targets that need it
$(GENERATED_DIR):
	@mkdir -p $(GENERATED_DIR)

# File dependencies
$(SCENARIOS_FILE): | $(GENERATED_DIR)
	@$(MAKE) -s generate

$(BULK_FILE): $(SCENARIOS_FILE)
	@$(MAKE) -s convert

$(PULLED_FILE):
	@$(MAKE) -s pull

# Phony targets (always run, don't represent files)
.PHONY: help generate generate-regression generate-gradual generate-all-separate \
		convert convert-all index index-direct verify-index pull pull-regression \
		pull-with-auth reindex test test-all test-gradual test-intermittent \
		compare-algorithms full-cycle practice-cycle round-trip view view-pulled \
		stats count list-indices clean clean-index clean-all-indices clean-all \
		reset exercise1 exercise2 exercise3 check-env show-files
