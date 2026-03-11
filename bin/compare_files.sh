#!/bin/bash

# Script to compare .json files, run.sh, and reg_expand.sh with files in another workspace
# Usage: ./compare_files.sh [SRC_REG_ROOT]
# or set SRC_REG_ROOT environment variable before running

# Check if SRC_REG_ROOT is provided as argument or environment variable
if [ -n "$1" ]; then
    SRC_REG_ROOT="$1"
elif [ -z "$SRC_REG_ROOT" ]; then
    echo "Error: SRC_REG_ROOT not provided"
    echo "Usage: $0 <source_workspace_root>"
    echo "   or: SRC_REG_ROOT=/path/to/source/workspace $0"
    exit 1
fi

# Verify SRC_REG_ROOT exists
if [ ! -d "$SRC_REG_ROOT" ]; then
    echo "Error: Source workspace root '$SRC_REG_ROOT' does not exist"
    exit 1
fi

# Get current directory
CURRENT_DIR="$(pwd)"

# Find the current workspace root (look for .git directory going up)
CURRENT_REG_ROOT="$CURRENT_DIR"
while [ "$CURRENT_REG_ROOT" != "/" ]; do
    if [ -d "$CURRENT_REG_ROOT/.git" ]; then
        break
    fi
    CURRENT_REG_ROOT="$(dirname "$CURRENT_REG_ROOT")"
done

if [ "$CURRENT_REG_ROOT" == "/" ] || [ ! -d "$CURRENT_REG_ROOT/.git" ]; then
    echo "Error: Could not find git root from current directory"
    exit 1
fi

# Get relative path from workspace root to current directory
REL_PATH="${CURRENT_DIR#$CURRENT_REG_ROOT/}"

# Replace 4IP with 4DPU in the relative path for source directory
SRC_REL_PATH="${REL_PATH//4IP/4DPU}"

# Construct source directory path
SRC_DIR="$SRC_REG_ROOT/$SRC_REL_PATH"

# Verify source directory exists
if [ ! -d "$SRC_DIR" ]; then
    echo "Error: Source directory '$SRC_DIR' does not exist"
    echo "  Current workspace root: $CURRENT_REG_ROOT"
    echo "  Relative path (current): $REL_PATH"
    echo "  Relative path (source): $SRC_REL_PATH"
    echo "  Source workspace root: $SRC_REG_ROOT"
    exit 1
fi

echo "Current workspace root: $CURRENT_REG_ROOT"
echo "Source workspace root: $SRC_REG_ROOT"
echo "Relative path (current): $REL_PATH"
echo "Relative path (source): $SRC_REL_PATH"
echo "================================"
echo "Comparing files in: $CURRENT_DIR"
echo "With source directory: $SRC_DIR"
echo "================================"
echo ""

# Counter for differences
DIFF_COUNT=0
SAME_COUNT=0
MISSING_COUNT=0

# Function to compare a file
compare_file() {
    local rel_path="$1"
    local current_file="$CURRENT_DIR/$rel_path"
    local src_file="$SRC_DIR/$rel_path"

    if [ ! -f "$src_file" ]; then
        echo "MISSING in SRC: $rel_path"
        ((MISSING_COUNT++))
        echo ""
        return
    fi

    if diff -q "$current_file" "$src_file" > /dev/null 2>&1; then
        echo "IDENTICAL: $rel_path"
        ((SAME_COUNT++))
    else
        echo "DIFFERENT: $rel_path"
        echo "-------------------"
        diff -u "$src_file" "$current_file" | head -50
        echo ""
        ((DIFF_COUNT++))
    fi
}

# Find and compare all .json files
while IFS= read -r -d '' file; do
    rel_path="${file#$CURRENT_DIR/}"
    compare_file "$rel_path"
done < <(find "$CURRENT_DIR" -maxdepth 1 -name "*.json" -type f -print0)

# Compare run.sh if it exists
if [ -f "$CURRENT_DIR/run.sh" ]; then
    compare_file "run.sh"
fi

# Compare reg_expand.sh if it exists
if [ -f "$CURRENT_DIR/reg_expand.sh" ]; then
    compare_file "reg_expand.sh"
fi

# Summary
echo "================================"
echo "SUMMARY:"
echo "  Identical files: $SAME_COUNT"
echo "  Different files: $DIFF_COUNT"
echo "  Missing in SRC: $MISSING_COUNT"
echo "================================"

# Exit with error code if there are differences
if [ $DIFF_COUNT -gt 0 ] || [ $MISSING_COUNT -gt 0 ]; then
    exit 1
else
    exit 0
fi
