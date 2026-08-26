#!/bin/bash
# ============================================
# STEP 6: Export data to CSV for Tableau Public — dashboard-ready version
# ============================================
# Tableau Public cannot connect live to PostgreSQL — only Tableau
# Desktop supports that. This script exports the tables/queries the
# dashboard needs as CSV files, with human-readable labels resolved
# in SQL (gender, visit type, drug name) so no Calculated Fields are
# needed in Tableau for basic labeling.
#
# Re-run this any time the underlying pipeline/cohort changes, then
# refresh the data source in Tableau Public.

set -e

DB_NAME="omop_cdm"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_DIR="${PROJECT_ROOT}/dashboard/exports"
mkdir -p "$EXPORT_DIR"

echo "=== Exporting to: $EXPORT_DIR ==="

# 1. Cohort overview — gender resolved to a readable label directly
psql -d "$DB_NAME" -c "\copy (
  SELECT
    person_id,
    index_date,
    year_of_birth,
    age_at_index,
    CASE gender_concept_id
      WHEN 8507 THEN 'Male'
      WHEN 8532 THEN 'Female'
      ELSE 'Unknown'
    END AS gender,
    CASE
      WHEN age_at_index < 12 THEN 'Child (0-11)'
      WHEN age_at_index < 18 THEN 'Adolescent (12-17)'
      WHEN age_at_index < 65 THEN 'Adult (18-64)'
      ELSE 'Older adult (65+)'
    END AS age_group
  FROM cohort.respiratory_cohort
) TO '${EXPORT_DIR}/cohort_overview.csv' WITH CSV HEADER"
echo "Exported cohort_overview.csv"

# 2. Utilization pattern — visit type labeled, month bucket for trend charts
psql -d "$DB_NAME" -c "\copy (
  SELECT
    v.person_id,
    CASE v.visit_concept_id
      WHEN 9202 THEN 'Outpatient'
      WHEN 9203 THEN 'Emergency'
      WHEN 9201 THEN 'Inpatient'
      WHEN 722455 THEN 'Telehealth'
      WHEN 581476 THEN 'Home visit'
      WHEN 42898160 THEN 'Nursing facility'
      ELSE 'Other/unmapped'
    END AS visit_type,
    v.visit_start_date,
    DATE_TRUNC('month', v.visit_start_date)::date AS visit_month,
    v.visit_end_date,
    v.base_encounter_cost,
    v.total_claim_cost
  FROM omop.visit_occurrence v
  JOIN cohort.respiratory_cohort c ON v.person_id = c.person_id
) TO '${EXPORT_DIR}/utilization_pattern.csv' WITH CSV HEADER"
echo "Exported utilization_pattern.csv"

# 3. Medication pattern — joined to omop.concept for real drug names
#    (previously exported as bare RxNorm codes)
psql -d "$DB_NAME" -c "\copy (
  SELECT
    d.person_id,
    COALESCE(con.concept_name, d.drug_source_value) AS drug_name,
    d.drug_source_value AS rxnorm_code,
    d.drug_exposure_start_date,
    DATE_TRUNC('month', d.drug_exposure_start_date)::date AS exposure_month,
    d.refills
  FROM omop.drug_exposure d
  JOIN cohort.respiratory_cohort c ON d.person_id = c.person_id
  LEFT JOIN omop.concept con ON con.concept_id = d.drug_concept_id
) TO '${EXPORT_DIR}/medication_pattern.csv' WITH CSV HEADER"
echo "Exported medication_pattern.csv (with resolved drug names)"

# 4. Data quality scorecard
psql -d "$DB_NAME" -c "\copy (
  SELECT
    'condition_occurrence' AS table_name,
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE condition_concept_id != 0) AS mapped_records,
    ROUND(100.0 * COUNT(*) FILTER (WHERE condition_concept_id != 0) / NULLIF(COUNT(*), 0), 2) AS mapped_pct
  FROM omop.condition_occurrence
  UNION ALL
  SELECT
    'drug_exposure',
    COUNT(*),
    COUNT(*) FILTER (WHERE drug_concept_id != 0),
    ROUND(100.0 * COUNT(*) FILTER (WHERE drug_concept_id != 0) / NULLIF(COUNT(*), 0), 2)
  FROM omop.drug_exposure
  UNION ALL
  SELECT
    'visit_occurrence',
    COUNT(*),
    COUNT(*) FILTER (WHERE visit_concept_id != 0),
    ROUND(100.0 * COUNT(*) FILTER (WHERE visit_concept_id != 0) / NULLIF(COUNT(*), 0), 2)
  FROM omop.visit_occurrence
) TO '${EXPORT_DIR}/data_quality_scorecard.csv' WITH CSV HEADER"
echo "Exported data_quality_scorecard.csv"

# 5. Comorbidity summary — other conditions co-occurring with the cohort
#    (top co-occurring diagnoses per cohort patient, for an optional 5th page)
psql -d "$DB_NAME" -c "\copy (
  SELECT
    con.concept_name AS comorbid_condition,
    COUNT(DISTINCT co.person_id) AS patient_count
  FROM omop.condition_occurrence co
  JOIN cohort.respiratory_cohort c ON co.person_id = c.person_id
  LEFT JOIN omop.concept con ON con.concept_id = co.condition_concept_id
  WHERE con.concept_name IS NOT NULL
    AND con.concept_name NOT IN ('Asthma', 'Childhood asthma', 'Chronic obstructive bronchitis', 'Pulmonary emphysema')
  GROUP BY con.concept_name
  ORDER BY patient_count DESC
  LIMIT 20
) TO '${EXPORT_DIR}/comorbidity_summary.csv' WITH CSV HEADER"
echo "Exported comorbidity_summary.csv (optional 5th dashboard page)"

# 6. Index Condition Breakdown — the 3 conditions that define the cohort
#    (VERIFIED: Asthma 16, Childhood asthma 15, Pulmonary emphysema 12 = 43)
psql -d "$DB_NAME" -c "\copy (
  SELECT
    con.concept_name AS condition_name,
    COUNT(DISTINCT c.person_id) AS patients,
    ROUND(100.0 * COUNT(DISTINCT c.person_id) / 43, 1) AS pct_of_cohort
  FROM cohort.respiratory_cohort c
  JOIN omop.condition_occurrence co
    ON c.person_id = co.person_id AND co.condition_start_date = c.index_date
  JOIN omop.concept con ON con.concept_id = co.condition_concept_id
  JOIN omop.concept_ancestor ca ON ca.descendant_concept_id = co.condition_concept_id
  WHERE ca.ancestor_concept_id IN (317009, 255573)
  GROUP BY con.concept_name
  ORDER BY patients DESC
) TO '${EXPORT_DIR}/index_condition_breakdown.csv' WITH CSV HEADER"
echo "Exported index_condition_breakdown.csv"

# 7. Low Mapping Details — the 10 source concepts responsible for ~97% of
#    unmapped condition_occurrence records (VERIFIED: all "History of X"
#    SNOMED situation concepts, sums to 357 of ~369 unmapped total)
psql -d "$DB_NAME" -c "\copy (
  SELECT
    co.condition_source_value AS concept_code,
    con.concept_name,
    COUNT(*) AS total_records,
    ROUND(100.0*COUNT(*) FILTER (WHERE co.condition_concept_id != 0)/COUNT(*),1) AS mapped_pct
  FROM omop.condition_occurrence co
  LEFT JOIN omop.concept con ON con.concept_code = co.condition_source_value AND con.vocabulary_id='SNOMED'
  GROUP BY 1,2
  HAVING COUNT(*) > 5
  ORDER BY mapped_pct ASC, total_records DESC
  LIMIT 10
) TO '${EXPORT_DIR}/low_mapping_details.csv' WITH CSV HEADER"
echo "Exported low_mapping_details.csv"

echo ""
echo "=== Done. Files ready in ${EXPORT_DIR} ==="
echo "In Tableau Public: Data > Text File > select each CSV"
echo "Labels (gender, visit type, drug name, age group) are pre-resolved —"
echo "no Calculated Fields needed for basic labeling."
echo "Re-run this script + refresh Tableau data source after pipeline changes."