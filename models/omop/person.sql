MODEL (
  name omop.person,
  kind FULL,
  grain (person_id),
  audits (
    UNIQUE_VALUES(columns = (person_id)),
    NOT_NULL(columns = (person_id, gender_concept_id, year_of_birth))
  )
);

-- Maps Synthea patients -> OMOP CDM v5.4 'person' table.
-- gender/race/ethnicity concept_ids below are the standard OMOP concept_ids
-- for these values (verify against your loaded vocabulary — these are the
-- commonly documented OHDSI standard concepts).

SELECT
  ROW_NUMBER() OVER (ORDER BY patient_id)     AS person_id,
  CASE gender_source_value
    WHEN 'M' THEN 8507   -- MALE
    WHEN 'F' THEN 8532   -- FEMALE
    ELSE 0
  END                                          AS gender_concept_id,
  EXTRACT(YEAR FROM birthdate)::int             AS year_of_birth,
  EXTRACT(MONTH FROM birthdate)::int             AS month_of_birth,
  EXTRACT(DAY FROM birthdate)::int                AS day_of_birth,
  birthdate::timestamp                              AS birth_datetime,
  0                                                   AS race_concept_id,       -- TODO: map race_source_value via concept table
  0                                                     AS ethnicity_concept_id, -- TODO: map ethnicity_source_value via concept table
  patient_id                                            AS person_source_value,
  gender_source_value                                     AS gender_source_value,
  race_source_value                                        AS race_source_value,
  ethnicity_source_value                                    AS ethnicity_source_value
FROM staging.stg_synthea__patients
