#!/bin/bash
# ============================================
# STEP 3: Create PostgreSQL database + OMOP CDM v5.4 schema
# ============================================
set -e

DB_NAME="omop_cdm"
SCHEMA_NAME="omop"

echo "=== Creating database: $DB_NAME ==="
createdb $DB_NAME || echo "Database may already exist, continuing..."

echo "=== Creating schema: $SCHEMA_NAME ==="
psql -d $DB_NAME -c "CREATE SCHEMA IF NOT EXISTS ${SCHEMA_NAME};"
psql -d $DB_NAME -c "CREATE SCHEMA IF NOT EXISTS raw;"
psql -d $DB_NAME -c "CREATE SCHEMA IF NOT EXISTS staging;"

echo "=== Downloading official OMOP CDM v5.4 DDL from OHDSI ==="
mkdir -p ~/omop-project/ddl
cd ~/omop-project/ddl

curl -L -o OMOPCDM_postgresql_5.4_ddl.sql \
    "https://raw.githubusercontent.com/OHDSI/CommonDataModel/main/inst/ddl/5.4/postgresql/OMOPCDM_postgresql_5.4_ddl.sql"

echo "=== Substituting schema placeholder (@cdmDatabaseSchema -> ${SCHEMA_NAME}) ==="
# The OHDSI DDL is a template — @cdmDatabaseSchema must be replaced with
# a real schema name before it will run. This is expected/normal, not
# an error in the downloaded file.
sed "s/@cdmDatabaseSchema/${SCHEMA_NAME}/g" OMOPCDM_postgresql_5.4_ddl.sql > OMOPCDM_postgresql_5.4_ddl_resolved.sql

echo "=== Applying DDL to create OMOP CDM tables ==="
psql -d $DB_NAME -f OMOPCDM_postgresql_5.4_ddl_resolved.sql

echo "=== Verifying tables created ==="
psql -d $DB_NAME -c "\dt ${SCHEMA_NAME}.*" | head -40

echo ""
echo "=== NEXT MANUAL STEP (cannot be scripted) ==="
echo "1. Go to https://athena.ohdsi.org and create a free account"
echo "2. Select vocabularies: SNOMED, RxNorm"
echo "3. Download the vocabulary bundle (a zip of CSV files)"
echo "4. Unzip into <project>/vocabulary/"
echo "5. Run setup/05_load_vocabulary.sh to load them into the '${SCHEMA_NAME}' schema"
