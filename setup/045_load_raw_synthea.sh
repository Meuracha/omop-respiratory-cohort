#!/bin/bash
# ============================================
# STEP 4.5 (before SQLMesh apply): Load raw Synthea CSVs
# into the 'raw' schema, so staging models have a source to read from.
# ============================================
# Usage: bash setup/045_load_raw_synthea.sh <path-to-synthea-csv-folder>
#
# NOTE: date/timestamp columns are loaded as TEXT, not native date types.
# Synthea occasionally generates implausible dates (e.g. year 2527) from
# a known bug in some chronic-condition duration calculations. Casting
# happens downstream in the staging models, where invalid dates are
# filtered out explicitly (a real, documented data-quality step) rather
# than silently failing the whole load here.

set -e

DB_NAME="omop_cdm"
CSV_DIR="$1"

if [ -z "$CSV_DIR" ]; then
    echo "Usage: bash setup/045_load_raw_synthea.sh <path-to-synthea-csv-folder>"
    exit 1
fi

if [ ! -f "$CSV_DIR/patients.csv" ]; then
    echo "ERROR: patients.csv not found in $CSV_DIR"
    exit 1
fi

echo "=== Creating raw tables (date/timestamp columns as TEXT — cast happens in staging) ==="

psql -d "$DB_NAME" <<'SQL'
CREATE SCHEMA IF NOT EXISTS raw;

DROP TABLE IF EXISTS raw.synthea_patients;
CREATE TABLE raw.synthea_patients (
    Id text, BIRTHDATE text, DEATHDATE text, SSN text, DRIVERS text,
    PASSPORT text, PREFIX text, FIRST text, MIDDLE text, LAST text,
    SUFFIX text, MAIDEN text, MARITAL text, RACE text, ETHNICITY text,
    GENDER text, BIRTHPLACE text, ADDRESS text, CITY text, STATE text,
    COUNTY text, FIPS text, ZIP text, LAT double precision, LON double precision,
    HEALTHCARE_EXPENSES numeric, HEALTHCARE_COVERAGE numeric, INCOME numeric
);

DROP TABLE IF EXISTS raw.synthea_conditions;
CREATE TABLE raw.synthea_conditions (
    START text, STOP text, PATIENT text, ENCOUNTER text,
    SYSTEM text, CODE text, DESCRIPTION text
);

DROP TABLE IF EXISTS raw.synthea_encounters;
CREATE TABLE raw.synthea_encounters (
    Id text, START text, STOP text, PATIENT text, ORGANIZATION text,
    PROVIDER text, PAYER text, ENCOUNTERCLASS text, CODE text, DESCRIPTION text,
    BASE_ENCOUNTER_COST numeric, TOTAL_CLAIM_COST numeric, PAYER_COVERAGE numeric,
    REASONCODE text, REASONDESCRIPTION text
);

DROP TABLE IF EXISTS raw.synthea_medications;
CREATE TABLE raw.synthea_medications (
    START text, STOP text, PATIENT text, PAYER text, ENCOUNTER text,
    CODE text, DESCRIPTION text, BASE_COST numeric, PAYER_COVERAGE numeric,
    DISPENSES int, TOTALCOST numeric, REASONCODE text, REASONDESCRIPTION text
);
SQL

echo "=== Loading CSVs from $CSV_DIR ==="

psql -d "$DB_NAME" -c "\copy raw.synthea_patients FROM '${CSV_DIR}/patients.csv' WITH CSV HEADER"
echo "Loaded patients.csv"

psql -d "$DB_NAME" -c "\copy raw.synthea_conditions FROM '${CSV_DIR}/conditions.csv' WITH CSV HEADER"
echo "Loaded conditions.csv"

psql -d "$DB_NAME" -c "\copy raw.synthea_encounters FROM '${CSV_DIR}/encounters.csv' WITH CSV HEADER"
echo "Loaded encounters.csv"

psql -d "$DB_NAME" -c "\copy raw.synthea_medications FROM '${CSV_DIR}/medications.csv' WITH CSV HEADER"
echo "Loaded medications.csv"

echo ""
echo "=== Row counts ==="
psql -d "$DB_NAME" -c "
SELECT 'patients' AS t, COUNT(*) FROM raw.synthea_patients
UNION ALL SELECT 'conditions', COUNT(*) FROM raw.synthea_conditions
UNION ALL SELECT 'encounters', COUNT(*) FROM raw.synthea_encounters
UNION ALL SELECT 'medications', COUNT(*) FROM raw.synthea_medications;
"

echo ""
echo "=== Checking for implausible dates (diagnostic only, not blocking) ==="
psql -d "$DB_NAME" -c "
SELECT COUNT(*) AS implausible_condition_dates
FROM raw.synthea_conditions
WHERE start !~ '^(19|20)[0-9]{2}-[0-9]{2}-[0-9]{2}\$'
   OR (stop IS NOT NULL AND stop != '' AND stop !~ '^(19|20)[0-9]{2}-[0-9]{2}-[0-9]{2}\$');
"

echo ""
echo "=== Done. Now run: sqlmesh plan ==="
