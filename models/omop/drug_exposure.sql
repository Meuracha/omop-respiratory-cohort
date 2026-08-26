MODEL (
  name omop.drug_exposure,
  kind FULL,
  grain (drug_exposure_id),
  audits (
    UNIQUE_VALUES(columns = (drug_exposure_id)),
    NOT_NULL(columns = (person_id, drug_concept_id, drug_exposure_start_date))
  )
);

-- Maps Synthea medications -> OMOP 'drug_exposure'.
-- medication_code from Synthea is RxNorm, which is the OMOP standard
-- vocabulary for drugs — same direct concept lookup pattern as conditions.

SELECT
  ROW_NUMBER() OVER (ORDER BY m.patient_id, m.start_date)  AS drug_exposure_id,
  p.person_id                                                 AS person_id,
  COALESCE(concept.concept_id, 0)                              AS drug_concept_id,
  m.start_date                                                  AS drug_exposure_start_date,
  m.start_date::timestamp                                        AS drug_exposure_start_datetime,
  COALESCE(m.end_date, m.start_date)                              AS drug_exposure_end_date,
  m.dispenses                                                      AS refills,
  m.medication_code                                                 AS drug_source_value,
  COALESCE(concept.concept_id, 0)                                    AS drug_source_concept_id
FROM staging.stg_synthea__medications m
JOIN omop.person p
  ON m.patient_id = p.person_source_value
LEFT JOIN omop.concept concept
  ON concept.concept_code = m.medication_code
  AND concept.vocabulary_id = 'RxNorm'
  AND concept.standard_concept = 'S'
