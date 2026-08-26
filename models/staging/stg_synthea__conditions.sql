MODEL (
  name staging.stg_synthea__conditions,
  kind VIEW,
  grain (patient_id, encounter_id, condition_code, start_date),
  audits (
    NOT_NULL(columns = (patient_id, condition_code))
  )
);

-- Source: raw Synthea conditions.csv (loaded as TEXT — see 045 setup script).
-- KNOWN DATA QUALITY ISSUE: Synthea occasionally generates implausible
-- dates (e.g. year 2527) from a bug in chronic-condition duration
-- calculations. Rows with an unparseable start_date are excluded here;
-- stop_date is nulled (not row-dropped) if unparseable, since an
-- ongoing condition with a bad stop date is still a valid record.
-- This filtering is itself a data-quality finding worth reporting in
-- the Data Quality Scorecard (see analysis/data_quality_checks.sql).
--
-- 'system' column is almost always http://snomed.info/sct — the
-- condition_code IS the OMOP standard vocabulary for conditions,
-- so mapping to OMOP concept_id is a direct lookup (see
-- models/omop/condition_occurrence.sql), not a cross-vocabulary
-- translation.

SELECT
  patient::text                                                      AS patient_id,
  encounter::text                                                     AS encounter_id,
  code::text                                                           AS condition_code,
  system::text                                                          AS condition_code_system,
  description::text                                                     AS condition_source_description,
  start::date                                                            AS start_date,
  CASE WHEN stop ~ '^(19|20)[0-9]{2}-[0-9]{2}-[0-9]{2}$'
       THEN stop::date END                                              AS end_date
FROM raw.synthea_conditions
WHERE start ~ '^(19|20)[0-9]{2}-[0-9]{2}-[0-9]{2}$'  -- exclude records with unparseable start_date
