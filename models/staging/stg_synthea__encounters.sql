MODEL (
  name staging.stg_synthea__encounters,
  kind VIEW,
  grain (encounter_id),
  audits (
    UNIQUE_VALUES(columns = (encounter_id)),
    NOT_NULL(columns = (encounter_id, patient_id))
  )
);

-- Source: raw Synthea encounters.csv (loaded as TEXT). Same implausible-
-- date issue as conditions; start_datetime is required (row excluded if
-- unparseable), end_datetime is nulled if unparseable but row kept.

SELECT
  id::text                                                             AS encounter_id,
  patient::text                                                         AS patient_id,
  encounterclass::text                                                   AS encounter_class_source_value,
  code::text                                                              AS encounter_code,
  description::text                                                       AS encounter_description,
  start::timestamp                                                        AS start_datetime,
  CASE WHEN stop ~ '^(19|20)[0-9]{2}-[0-9]{2}-[0-9]{2}'
       THEN stop::timestamp END                                          AS end_datetime,
  base_encounter_cost::numeric                                            AS base_cost,
  total_claim_cost::numeric                                               AS total_claim_cost,
  payer_coverage::numeric                                                 AS payer_coverage
FROM raw.synthea_encounters
WHERE start ~ '^(19|20)[0-9]{2}-[0-9]{2}-[0-9]{2}'  -- exclude records with unparseable start_datetime
