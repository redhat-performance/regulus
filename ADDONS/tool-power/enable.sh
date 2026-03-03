#!/bin/bash
# Enable tool-power on a Regulus run directory
#
# Usage: ./enable-power-collection.sh <run-directory> <tool-power.json>

set -e

RUN_DIR="${1}"
TOOL_POWER_JSON="${2}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function usage() {
    cat << EOF
Usage: $0 <run-directory> <tool-power.json>

Merges tool-power.json into tool-params.json in the specified run directory.

Arguments:
  run-directory     Path to Regulus run directory (e.g., \$REG_ROOT/X_GROUP/.../Y-POD)
  tool-power.json   Path to tool-power.json file with BMC configuration

Examples:
  # Using username/password authentication
  $0 \$REG_ROOT/1_GROUP/NO-PAO/4IP/INTRA-NODE/TCP/2-POD tool-power.json

  # Using .netrc authentication (also need hostmount.json)
  $0 \$REG_ROOT/1_GROUP/NO-PAO/4IP/INTRA-NODE/TCP/2-POD tool-power.json

Templates:
  - templates/tool-power.json.template (with user/password)
  - templates/tool-power-netrc.json.template (using .netrc)
  - templates/hostmount.json.template (for .netrc mounting)

EOF
    exit 1
}

# Check arguments
if [ -z "$RUN_DIR" ] || [ -z "$TOOL_POWER_JSON" ]; then
    echo -e "${RED}ERROR: Missing required arguments${NC}"
    echo ""
    usage
fi

if [ ! -d "$RUN_DIR" ]; then
    echo -e "${RED}ERROR: Run directory not found: $RUN_DIR${NC}"
    exit 1
fi

if [ ! -f "$TOOL_POWER_JSON" ]; then
    echo -e "${RED}ERROR: tool-power.json not found: $TOOL_POWER_JSON${NC}"
    exit 1
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}ERROR: jq is required but not installed${NC}"
    echo "Install with: yum install jq  (or)  dnf install jq"
    exit 1
fi

TOOL_PARAMS_FILE="$RUN_DIR/tool-params.json"

echo "==========================================="
echo "Enable Power Collection for Regulus Run"
echo "==========================================="
echo ""
echo "Run directory: $RUN_DIR"
echo "Tool-power config: $TOOL_POWER_JSON"
echo ""

# Step 1: Check and insert POWER snippet into run.sh
echo "[Step 1/4] Checking run.sh for POWER snippet..."
RUN_SH_FILE="$RUN_DIR/run.sh"

if [ ! -f "$RUN_SH_FILE" ]; then
    echo -e "  ${RED}ERROR: run.sh not found in $RUN_DIR${NC}"
    exit 1
fi

if grep -q "POWER=1" "$RUN_SH_FILE"; then
    echo "  ✓ POWER snippet already exists in run.sh"
else
    echo "  ℹ POWER snippet not found, inserting..."

    # Find the line before "ARGS=" and insert POWER snippet
    if grep -q "^ARGS=" "$RUN_SH_FILE"; then
        # Find the line number where ARGS= appears
        LINE_NUM=$(grep -n "^ARGS=" "$RUN_SH_FILE" | head -1 | cut -d: -f1)

        # Create temporary file with POWER snippet inserted
        {
            head -n $((LINE_NUM - 1)) "$RUN_SH_FILE"
            cat << 'POWER_SNIPPET_EOF'

POWER=1
    if [ "${POWER:-0}" = "1" ]; then
        endpoint_opt+=" --endpoint remotehosts,user:root,host:$bmlhosta,profiler:1-$num_servers,userenv:$userenv,tool-opt-in-tags:[power-monitoring],host-mounts:`pwd`/hostmount.json"
    fi

POWER_SNIPPET_EOF
            tail -n +$LINE_NUM "$RUN_SH_FILE"
        } > "$RUN_SH_FILE.tmp"

        mv "$RUN_SH_FILE.tmp" "$RUN_SH_FILE"
        echo "  ✓ Inserted POWER snippet into run.sh"
    else
        echo -e "  ${YELLOW}⚠ Could not find ARGS= line in run.sh${NC}"
        echo "  Please manually add the POWER snippet before the ARGS= line"
    fi
fi
echo ""

# Step 2: Check existing tool-params.json
echo "[Step 2/4] Checking tool-params.json..."
if [ -f "$TOOL_PARAMS_FILE" ]; then
    echo "  ✓ Found existing tool-params.json"
else
    echo "  ℹ No existing tool-params.json, will create new one"
    echo '[]' > "$TOOL_PARAMS_FILE"
fi
echo ""

# Step 3: Check if power tool already exists
echo "[Step 3/4] Checking for existing power tool configuration..."
if jq -e '.[] | select(.tool == "power")' "$TOOL_PARAMS_FILE" &> /dev/null; then
    echo -e "  ${YELLOW}⚠ Power tool already configured in tool-params.json${NC}"
    echo ""
    read -p "  Replace existing power tool configuration? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "  Aborted."
        exit 0
    fi
    # Remove existing power tool entry
    TEMP_FILE=$(mktemp)
    jq 'map(select(.tool != "power"))' "$TOOL_PARAMS_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$TOOL_PARAMS_FILE"
    echo "  ✓ Removed existing power tool configuration"
else
    echo "  ✓ No existing power tool found"
fi
echo ""

# Step 4: Merge tool-power.json into tool-params.json
echo "[Step 4/4] Merging tool-power.json into tool-params.json..."
TEMP_FILE=$(mktemp)
jq --slurpfile power "$TOOL_POWER_JSON" '. + $power' "$TOOL_PARAMS_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$TOOL_PARAMS_FILE"
echo "  ✓ Successfully merged"
echo ""

# Summary
echo "==========================================="
echo -e "${GREEN}✓ Power collection enabled successfully!${NC}"
echo "==========================================="
echo ""
echo "Modified files:"
echo "  - $RUN_SH_FILE"
echo "  - $TOOL_PARAMS_FILE"
echo ""
echo "Next steps:"
echo "  1. Verify tool-params.json: cat $TOOL_PARAMS_FILE"
echo "  2. If using .netrc authentication:"
echo "     - Ensure .netrc exists on remotehost with BMC credentials"
echo "     - Copy hostmount.json to run directory if needed"
echo "  3. Run your benchmark: cd $RUN_DIR && ./run.sh"
echo ""
