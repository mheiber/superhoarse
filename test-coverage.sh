#!/bin/bash

# Test Coverage Analysis Script for Superhoarse
# Usage: ./test-coverage.sh

set -e

echo "Running tests with coverage..."
swift test --enable-code-coverage

echo ""
echo "=== Test Coverage Summary ==="
echo ""

# Extract coverage for our main source files only
jq -r '.data[].files[] | select(.filename | contains("/Users/mheiber/mnt/superhoarse/Sources/")) | 
    "\(.filename | split("/") | last): \(.summary.functions.percent | floor)% functions, \(.summary.lines.percent | floor)% lines"' \
    .build/arm64-apple-macosx/debug/codecov/Superhoarse.json | sort

echo ""
echo "=== Overall Coverage Stats ==="

# Calculate totals
total_functions=$(jq '.data[].files[] | select(.filename | contains("/Users/mheiber/mnt/superhoarse/Sources/")) | .summary.functions.count' .build/arm64-apple-macosx/debug/codecov/Superhoarse.json | awk '{sum+=$1} END {print sum}')
covered_functions=$(jq '.data[].files[] | select(.filename | contains("/Users/mheiber/mnt/superhoarse/Sources/")) | .summary.functions.covered' .build/arm64-apple-macosx/debug/codecov/Superhoarse.json | awk '{sum+=$1} END {print sum}')

total_lines=$(jq '.data[].files[] | select(.filename | contains("/Users/mheiber/mnt/superhoarse/Sources/")) | .summary.lines.count' .build/arm64-apple-macosx/debug/codecov/Superhoarse.json | awk '{sum+=$1} END {print sum}')
covered_lines=$(jq '.data[].files[] | select(.filename | contains("/Users/mheiber/mnt/superhoarse/Sources/")) | .summary.lines.covered' .build/arm64-apple-macosx/debug/codecov/Superhoarse.json | awk '{sum+=$1} END {print sum}')

function_percent=$(echo "scale=1; ($covered_functions * 100) / $total_functions" | bc -l)
line_percent=$(echo "scale=1; ($covered_lines * 100) / $total_lines" | bc -l)

echo "Total Functions: $covered_functions/$total_functions ($function_percent%)"
echo "Total Lines: $covered_lines/$total_lines ($line_percent%)"

echo ""
echo "Coverage report saved at: $(swift test --enable-code-coverage --show-code-coverage-path)"