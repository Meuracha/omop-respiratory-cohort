-- ============================================================
-- Data Quality Scorecard
-- ============================================================
-- Run these after the SQLMesh models have built. Results feed
-- the "Data Quality Scorecard" Tableau page.

-- 1. Concept mapping success rate (conditions)
SELECT
  'condition_occurrence' AS table_name,
  COUNT(*) AS total_records,
  COUNT(*) FILTER (WHERE condition_concept_id != 0) AS mapped_records,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE condition_concept_id != 0) / NULLIF(COUNT(*), 0),
    2
  ) AS mapped_pct
FROM omop.condition_occurrence

UNION ALL

SELECT
  'drug_exposure' AS table_name,
  COUNT(*) AS total_records,
  COUNT(*) FILTER (WHERE drug_concept_id != 0) AS mapped_records,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE drug_concept_id != 0) / NULLIF(COUNT(*), 0),
    2
  ) AS mapped_pct
FROM omop.drug_exposure

UNION ALL

SELECT
  'visit_occurrence' AS table_name,
  COUNT(*) AS total_records,
  COUNT(*) FILTER (WHERE visit_concept_id != 0) AS mapped_records,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE visit_concept_id != 0) / NULLIF(COUNT(*), 0),
    2
  ) AS mapped_pct
FROM omop.visit_occurrence;

-- 2. Referential integrity: every condition/visit/drug should trace to a real person
SELECT 'orphan_conditions' AS check_name, COUNT(*) AS violation_count
FROM omop.condition_occurrence co
LEFT JOIN omop.person p ON co.person_id = p.person_id
WHERE p.person_id IS NULL

UNION ALL

SELECT 'orphan_visits', COUNT(*)
FROM omop.visit_occurrence v
LEFT JOIN omop.person p ON v.person_id = p.person_id
WHERE p.person_id IS NULL;

-- 3. Date logic: condition_start_date should never precede birth_datetime
SELECT COUNT(*) AS date_logic_violations
FROM omop.condition_occurrence co
JOIN omop.person p ON co.person_id = p.person_id
WHERE co.condition_start_date < p.birth_datetime::date;

-- 4. Null rate per key column (person table example — extend per table as needed)
SELECT
  COUNT(*) AS total_rows,
  COUNT(*) FILTER (WHERE gender_concept_id IS NULL OR gender_concept_id = 0) AS missing_gender,
  COUNT(*) FILTER (WHERE year_of_birth IS NULL) AS missing_birth_year
FROM omop.person;