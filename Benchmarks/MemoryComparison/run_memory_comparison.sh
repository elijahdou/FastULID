#!/bin/bash

#
# run_memory_comparison.sh
# Memory comparison benchmark between FastULID and yaslab/ULID.swift
#
# Created on 2025-12-04.
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "🔧 Preparing memory comparison test environment..."
echo ""

if [ -d ".build" ]; then
    echo "🧹 Cleaning old build artifacts..."
    rm -rf .build
fi

echo "📦 Resolving package dependencies..."
swift package resolve

echo ""
echo "🏗️  Building release version..."
swift build -c release

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║                     Running Memory Comparison Test                            ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
echo ""

swift run -c release MemoryComparison

echo ""
echo "✅ Memory comparison test completed!"
echo ""
echo "💡 Tips:"
echo "   - Memory measurements may be affected by system state"
echo "   - Run multiple times and average for best accuracy"
echo "   - Close other applications for more accurate results"
echo "   - Use Instruments for detailed memory profiling"
echo ""

