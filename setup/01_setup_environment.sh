#!/bin/bash
# ============================================
# STEP 1: Environment Setup (Mac M1/M2/M3)
# ============================================
set -e

echo "=== Checking prerequisites ==="
# Java (required for Synthea)
if ! command -v java &> /dev/null; then
    echo "Installing Java via Homebrew..."
    brew install openjdk@21
    echo 'export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"' >> ~/.zshrc
    source ~/.zshrc
fi
java -version

# PostgreSQL
if ! command -v psql &> /dev/null; then
    echo "Installing PostgreSQL via Homebrew..."
    brew install postgresql@16
    brew services start postgresql@16
fi

# Python for SQLMesh
if ! command -v python3 &> /dev/null; then
    echo "Python3 not found - install via 'brew install python3'"
    exit 1
fi
python3 --version

echo "=== Prerequisites OK ==="
