# Makefile for build_report project
# Core report generation ONLY

.PHONY: help test clean

# Configuration variables
PYTHON := python3
TEST_DATA_DIR := test_data
OUTPUT_DIR ?= /tmp

# Default target
help:
	@echo "====================================================================="
	@echo "  Build Report - Core Report Generation"
	@echo "====================================================================="
	@echo ""
	@echo "Note: This makefile only handles core report generation."
	@echo "For dashboard, ES integration, and MCP server, use REPORT/makefile"
	@echo ""
	@echo "Report generation is handled via the build_report CLI script:"
	@echo "  bash build_report --formats html csv --output <path>"
	@echo ""
	@echo "Available targets:"
	@echo "  make test    - Run unit tests"
	@echo "  make clean   - Clean temporary files"
	@echo ""
	@echo "For full workflow, use targets in REPORT/makefile:"
	@echo "  cd .. && make help"
	@echo "====================================================================="

# =============================================================================
# Testing Targets
# =============================================================================

test:
	@echo "Running build_report tests..."
	@echo "✓ No tests defined yet"

# =============================================================================
# Maintenance Targets
# =============================================================================

clean:
	@echo "Cleaning temporary files in build_report/..."
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo "✓ Cleanup complete"
