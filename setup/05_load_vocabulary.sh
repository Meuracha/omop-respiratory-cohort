#!/bin/bash
# ============================================
# STEP 5: Load OMOP Vocabulary CSVs into PostgreSQL
# ============================================
# Run this AFTER setup/03_setup_postgres_omop.sh (which creates the
# 'vocabulary' schema and its table structures via the OHDSI DDL).
#
# IMPORTANT: Athena's "CSV" files are actually TAB-delimited, not
# comma-delimited. This script gets that right — don't load them
# with a plain comma delimiter or every column will be misaligned.

set -e

DB_NAME="omop_cdm"
SCHEMA_NAME="omop"
VOCAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../vocabulary" && pwd)"

echo "=== Loading vocabulary files from: $VOCAB_DIR into schema '${SCHEMA_NAME}' ==="

# Order matters for some tables due to FK-style relationships in queries,
# though OMOP vocabulary tables typically don't enforce hard FKs — this
# order just loads the small reference tables first.
declare -a TABLES=(
    "DOMAIN:domain"
    "CONCEPT_CLASS:concept_class"
    "VOCABULARY:vocabulary"
    "RELATIONSHIP:relationship"
    "CONCEPT:concept"
    "CONCEPT_RELATIONSHIP:concept_relationship"
    "CONCEPT_SYNONYM:concept_synonym"
    "CONCEPT_ANCESTOR:concept_ancestor"
    "DRUG_STRENGTH:drug_strength"
)

for entry in "${TABLES[@]}"; do
    FILE_NAME="${entry%%:*}"
    TABLE_NAME="${entry##*:}"
    CSV_PATH="$VOCAB_DIR/${FILE_NAME}.csv"

    if [ ! -f "$CSV_PATH" ]; then
        echo "WARNING: $CSV_PATH not found — skipping"
        continue
    fi

    echo "Loading ${FILE_NAME}.csv -> omop.${TABLE_NAME} ..."
    psql -d "$DB_NAME" -c "TRUNCATE TABLE omop.${TABLE_NAME} CASCADE;"
    psql -d "$DB_NAME" -c "\copy omop.${TABLE_NAME} FROM '${CSV_PATH}' WITH (FORMAT csv, DELIMITER E'\t', HEADER true, QUOTE E'\b', NULL '')"
done

echo ""
echo "=== Verifying row counts ==="
psql -d "$DB_NAME" -c "
SELECT 'concept' AS table_name, COUNT(*) FROM omop.concept
UNION ALL
SELECT 'concept_ancestor', COUNT(*) FROM omop.concept_ancestor
UNION ALL
SELECT 'concept_relationship', COUNT(*) FROM omop.concept_relationship
UNION ALL
SELECT 'drug_strength', COUNT(*) FROM omop.drug_strength;
"

echo ""
echo "=== Quick sanity check: find SNOMED concept for Asthma ==="
psql -d "$DB_NAME" -c "
SELECT concept_id, concept_name, vocabulary_id, standard_concept
FROM omop.concept
WHERE vocabulary_id = 'SNOMED'
  AND concept_name ILIKE 'Asthma'
  AND standard_concept = 'S';
"
