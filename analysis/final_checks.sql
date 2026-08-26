-- ============================================================
-- Pre-Dashboard Checklist
-- ============================================================
-- Run before building Tableau. Covers things not yet checked:
-- cohort demographic sanity, visit concept mapping, future-date
-- leakage, and whether cohort patients actually have enough
-- visit/medication data to populate those dashboard pages.

-- 1. Cohort age/gender distribution — sanity check for implausible
--    ages (negative, or absurdly high) and to preview how thin the
--    demographic breakdowns will be at n=43.
SELECT
  gender_concept_id,
  MIN(age_at_index) AS min_age,
  MAX(age_at_index) AS max_age,
  ROUND(AVG(age_at_index), 1) AS avg_age,
  COUNT(*) AS n
FROM cohort.respiratory_cohort
GROUP BY gender_concept_id;

-- 2. Any implausible ages (negative, or > 110)?
SELECT COUNT(*) AS implausible_ages
FROM cohort.respiratory_cohort
WHERE age_at_index < 0 OR age_at_index > 110;

-- 3. Visit concept mapping rate — encounter_class_source_value values
--    not covered by the CASE mapping in models/omop/visit_occurrence.sql
--    fall through to visit_concept_id = 0. Check how common that is.
SELECT
  visit_concept_id,
  COUNT(*) AS n
FROM omop.visit_occurrence
GROUP BY visit_concept_id
ORDER BY n DESC;

-- 4. Any dates in the future (beyond today)? Would indicate a data
--    generation or casting issue, not caught by the earlier
--    birth-date logic check.
SELECT COUNT(*) AS future_dated_conditions
FROM omop.condition_occurrence
WHERE condition_start_date > CURRENT_DATE;

SELECT COUNT(*) AS future_dated_visits
FROM omop.visit_occurrence
WHERE visit_start_date > CURRENT_DATE;

-- 5. Coverage: how many cohort patients actually have at least one
--    visit / one medication? If this is low, the Utilization and
--    Medication Pattern dashboard pages will look sparse or empty
--    for most patients.
SELECT
  COUNT(DISTINCT c.person_id) AS cohort_size,
  COUNT(DISTINCT v.person_id) AS with_visits,
  COUNT(DISTINCT d.person_id) AS with_medications
FROM cohort.respiratory_cohort c
LEFT JOIN omop.visit_occurrence v ON c.person_id = v.person_id
LEFT JOIN omop.drug_exposure d ON c.person_id = d.person_id;

-- 6. Index date distribution — check cohort diagnoses aren't all
--    clustered on one implausible date (would suggest a join bug).
SELECT
  MIN(index_date) AS earliest,
  MAX(index_date) AS latest,
  COUNT(DISTINCT index_date) AS distinct_dates
FROM cohort.respiratory_cohort;