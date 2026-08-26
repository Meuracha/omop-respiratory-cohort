MODEL (
  name omop.visit_occurrence,
  kind FULL,
  grain (visit_occurrence_id),
  audits (
    UNIQUE_VALUES(columns = (visit_occurrence_id)),
    NOT_NULL(columns = (person_id, visit_concept_id, visit_start_date))
  )
);

-- Maps Synthea encounters -> OMOP 'visit_occurrence'.
-- encounter_class_source_value values from Synthea: ambulatory, emergency,
-- inpatient, wellness, urgentcare, outpatient, home, hospice, snf, virtual.
-- Concept_ids below were verified against the loaded vocabulary
-- (domain_id='Visit', standard_concept='S') — not assumed from memory.
-- 'hospice' has no matching standard Visit concept in the loaded
-- vocabulary; left unmapped (0) rather than forced onto an inexact
-- concept (e.g. Office Visit), since hospice care is not an office
-- visit. This is a known, documented gap — see Data Quality Scorecard.

SELECT
  ROW_NUMBER() OVER (ORDER BY e.patient_id, e.start_datetime)  AS visit_occurrence_id,
  p.person_id                                                     AS person_id,
  CASE e.encounter_class_source_value
    WHEN 'inpatient'   THEN 9201
    WHEN 'emergency'   THEN 9203
    WHEN 'ambulatory'  THEN 9202
    WHEN 'wellness'    THEN 9202
    WHEN 'outpatient'  THEN 9202
    WHEN 'urgentcare'  THEN 9203
    WHEN 'home'        THEN 581476
    WHEN 'snf'         THEN 42898160
    WHEN 'virtual'     THEN 722455
    ELSE 0  -- includes 'hospice' — no exact standard Visit concept available
  END                                                               AS visit_concept_id,
  e.start_datetime::date                                             AS visit_start_date,
  e.start_datetime                                                     AS visit_start_datetime,
  e.end_datetime::date                                                  AS visit_end_date,
  e.end_datetime                                                         AS visit_end_datetime,
  e.encounter_id                                                          AS visit_source_value,
  e.base_cost                                                              AS base_encounter_cost,
  e.total_claim_cost                                                        AS total_claim_cost,
  e.payer_coverage                                                           AS payer_coverage
FROM staging.stg_synthea__encounters e
JOIN omop.person p
  ON e.patient_id = p.person_source_value