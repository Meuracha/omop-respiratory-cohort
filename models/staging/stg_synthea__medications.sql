MODEL (
  name staging.stg_synthea__medications,
  kind VIEW,
  grain (patient_id, encounter_id, medication_code, start_date),
  audits (
    NOT_NULL(columns = (patient_id, medication_code))
  )
);

-- Source: raw Synthea medications.csv (loaded as TEXT). Same implausible-
-- date pattern as conditions/encounters.
-- Codes here are RxNorm — OMOP standard vocabulary for drug_exposure,
-- same direct-lookup pattern as conditions/SNOMED.

SELECT
  patient::text                                                        AS patient_id,
  encounter::text                                                       AS encounter_id,
  code::text                                                             AS medication_code,
  description::text                                                      AS medication_source_description,
  start::date                                                             AS start_date,
  CASE WHEN stop ~ '^(19|20)[0-9]{2}-[0-9]{2}-[0-9]{2}'
       THEN stop::date END                                               AS end_date,
  dispenses::int                                                          AS dispenses,
  totalcost::numeric                                                      AS total_cost
FROM raw.synthea_medications
WHERE start ~ '^(19|20)[0-9]{2}-[0-9]{2}-[0-9]{2}'  -- exclude records with unparseable start_date (note: no trailing $, since Synthea medication dates include a time component e.g. 'YYYY-MM-DDTHH:MI:SSZ')