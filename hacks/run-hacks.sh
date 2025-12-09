#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Running all hack scripts..."
echo ""

echo "1. Running nomad-fix.sh..."
bash "$SCRIPT_DIR/nomad-fix.sh"
echo ""

echo "2. Running policy-service-fix.sh..."
bash "$SCRIPT_DIR/policy-service-fix.sh"
echo ""

echo "All hacks completed successfully!"

