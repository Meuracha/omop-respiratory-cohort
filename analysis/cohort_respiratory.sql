-- ============================================================
-- Respiratory Disease Cohort Definition (Asthma / COPD)
-- ============================================================
-- Uses OMOP's concept_ancestor table to capture ALL descendant
-- concepts of the target conditions, not just the exact codes
-- observed in the raw data. This is the standard OHDSI approach
-- to cohort definition (rather than hardcoding a fixed ICD-10/
-- SNOMED code list).
--
-- Target ancestor concepts (verify concept_id against your
-- loaded vocabulary — these are the commonly documented SNOMED
-- standard concept_ids for these conditions):
--   317009  = Asthma
--   255573  = Chronic obstructive lung disease (COPD)

CREATE SCHEMA IF NOT EXISTS cohort;

DROP TABLE IF EXISTS cohort.respiratory_cohort;

CREATE TABLE cohort.respiratory_cohort AS
WITH target_concepts AS (
  SELECT descendant_concept_id AS concept_id
  FROM omop.concept_ancestor
  WHERE ancestor_concept_id IN (317009, 255573)
),
first_diagnosis AS (
  SELECT
    co.person_id,
    MIN(co.condition_start_date) AS index_date
  FROM omop.condition_occurrence co
  JOIN target_concepts tc
    ON co.condition_concept_id = tc.concept_id
  GROUP BY co.person_id
)
SELECT
  fd.person_id,
  fd.index_date,
  p.year_of_birth,
  p.gender_concept_id,
  (EXTRACT(YEAR FROM fd.index_date) - p.year_of_birth) AS age_at_index
FROM first_diagnosis fd
JOIN omop.person p
  ON fd.person_id = p.person_id;

-- Quick sanity check after running:
-- SELECT COUNT(*) AS cohort_size FROM cohort.respiratory_cohort;
