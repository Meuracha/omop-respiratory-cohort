MODEL (
  name staging.stg_synthea__patients,
  kind VIEW,
  grain (patient_id),
  audits (
    UNIQUE_VALUES(columns = (patient_id)),
    NOT_NULL(columns = (patient_id, birthdate))
  )
);

-- Source: raw Synthea patients.csv, loaded as TEXT into raw.synthea_patients.
-- Dates are cast here with a plausibility filter (1900-2029) because
-- Synthea occasionally emits implausible dates (see staging conditions
-- model for the same issue observed there).

SELECT
  id::text                                                          AS patient_id,
  CASE WHEN birthdate ~ '^(19|20)[0-9]{2}-[0-9]{2}-[0-9]{2}$'
       THEN birthdate::date END                                      AS birthdate,
  CASE WHEN deathdate ~ '^(19|20)[0-9]{2}-[0-9]{2}-[0-9]{2}$'
       THEN deathdate::date END                                       AS deathdate,
  gender::text                                                          AS gender_source_value,
  race::text                                                             AS race_source_value,
  ethnicity::text                                                         AS ethnicity_source_value,
  city::text                                                               AS city,
  state::text                                                               AS state,
  zip::text                                                                  AS zip
FROM raw.synthea_patients
WHERE birthdate ~ '^(19|20)[0-9]{2}-[0-9]{2}-[0-9]{2}$'  -- exclude records with unparseable birthdate
