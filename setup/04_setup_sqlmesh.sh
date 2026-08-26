#!/bin/bash
# ============================================
# STEP 4: SQLMesh project setup
# ============================================
set -e

cd ~/omop-project

echo "=== Creating Python virtual environment ==="
python3 -m venv sqlmeshenv
source sqlmeshenv/bin/activate

echo "=== Installing SQLMesh with Postgres support ==="
pip install "sqlmesh[web,postgres]"

echo "=== Initializing SQLMesh project ==="
sqlmesh init postgres

echo ""
echo "=== NEXT STEPS ==="
echo "1. Edit config.yaml with your Postgres connection details (db: omop_cdm)"
echo "2. Load raw Synthea CSVs into a 'staging' schema first (use psql \copy or Python/pandas)"
echo "3. Reference the team's public pattern for inspiration (read-only, for architecture reference):"
echo "   https://github.com/sidataplus/demo-etl-sqlmesh-omop-synthea"
echo "4. Write your own staging models in ./models/ that:"
echo "   - Map Synthea 'conditions' -> OMOP 'condition_occurrence'"
echo "     (join SYSTEM/CODE against concept table WHERE vocabulary_id='SNOMED')"
echo "   - Map Synthea 'patients' -> OMOP 'person'"
echo "   - Map Synthea 'encounters' -> OMOP 'visit_occurrence'"
echo "   - Map Synthea 'medications' -> OMOP 'drug_exposure'"
