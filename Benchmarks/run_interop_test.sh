#!/bin/bash
set -e

# Compile Swift
echo "Compiling Swift..."
swift build -c release --product CrossLanguageValidation

SWIFT_BIN=$(swift build -c release --show-bin-path)/CrossLanguageValidation
PYTHON_SCRIPT="CrossLanguageValidation/verify_ulid.py"

echo "--------------------------------------------------"
echo "Test 1: Swift Generation -> Python Validation"
echo "--------------------------------------------------"
$SWIFT_BIN generate 100 > swift_ulids.txt
python3 $PYTHON_SCRIPT validate < swift_ulids.txt

echo ""
echo "--------------------------------------------------"
echo "Test 2: Python Generation -> Swift Validation"
echo "--------------------------------------------------"
python3 $PYTHON_SCRIPT generate 100 > python_ulids.txt
$SWIFT_BIN validate < python_ulids.txt

echo ""
echo "✅ Cross-language validation passed!"
rm swift_ulids.txt python_ulids.txt

