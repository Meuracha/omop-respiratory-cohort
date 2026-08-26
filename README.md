# Respiratory Disease Cohort Analytics — OMOP CDM Pipeline

A portfolio project demonstrating an end-to-end healthcare data pipeline:
synthetic patient data → OMOP Common Data Model → cohort analytics →
Tableau dashboard.

## Why this project

Built to demonstrate familiarity with the tools and standards used in
hospital data teams (SQLMesh, OMOP CDM, OHDSI vocabularies), extended
with an analytics/dashboard layer aimed at non-technical stakeholders —
the piece that pure backend ETL demos typically stop short of.

## Architecture

```
Synthea (synthetic patient generator)
        ↓  raw CSV
PostgreSQL — raw schema
        ↓  SQLMesh staging models
staging schema (typed, standardized columns)
        ↓  SQLMesh OMOP models + OHDSI vocabulary lookup
omop schema (OMOP CDM v5.4: person, condition_occurrence,
             visit_occurrence, drug_exposure)
        ↓  cohort definition (concept_ancestor traversal)
cohort schema (respiratory_cohort: asthma / COPD patients)
        ↓
Tableau dashboard
```

## Data source

**Synthea** (Apache 2.0 license) — a synthetic patient generator. No real
patient data is used anywhere in this project. Clinical patterns
(disease incidence, treatment pathways) in Synthea are modeled on US
clinical guidelines, so this project should be read as a **technical
standards demo** (OMOP CDM, ETL, cohort analytics), not as a study of
Thai population health. See `analysis/` for the explicit scope note.

## Setup

Run in order — see `setup/` for full scripts:

1. `setup/01_setup_environment.sh` — Java, PostgreSQL, Python (Homebrew)
2. `setup/02_generate_synthea_data.sh` — generates a 500-patient
   validation batch first; re-run at larger scale once the pipeline
   is validated end-to-end
3. `setup/03_setup_postgres_omop.sh` — creates the OMOP CDM v5.4 schema
   from the official OHDSI DDL. **Manual step required here:** register
   at [athena.ohdsi.org](https://athena.ohdsi.org), download the SNOMED
   + RxNorm vocabularies, and load them into the `vocabulary` schema
   (this cannot be scripted — Athena requires a logged-in download)
4. `setup/04_setup_sqlmesh.sh` — sets up the SQLMesh project

Then load the raw Synthea CSVs into `raw.*` tables (`psql \copy` or a
short Python/pandas loader — not included, since the exact command
depends on where you generated the CSVs), and run:

```
sqlmesh plan
sqlmesh apply
```

## Cohort definition

`analysis/cohort_respiratory.sql` — defines the cohort using
`concept_ancestor` traversal from two anchor concepts (Asthma, COPD),
rather than hardcoding a fixed list of source codes. This follows the
standard OHDSI cohort-definition pattern.

## Data quality

`analysis/data_quality_checks.sql` — concept-mapping success rate,
referential integrity, and date-logic checks. Results feed the "Data
Quality Scorecard" page of the dashboard.

## Dashboard

**Note on Tableau connectivity:** Tableau Public (the free tier used for
this project) does not support a live PostgreSQL connection — that
requires Tableau Desktop. The workflow here is: run the SQLMesh models
and cohort/data-quality SQL in `analysis/`, then export the resulting
mart tables to CSV (`setup/06_export_for_tableau.sh`), and load those
CSVs into Tableau Public directly. This means the dashboard is a
snapshot, not live — re-run the export after any pipeline change.

`dashboard/` — Tableau workbook (add `.twbx` here once built). Planned
pages:
1. Cohort Overview (demographics, size)
2. Data Quality Scorecard
3. Utilization Pattern (visit frequency, class breakdown)
4. Medication Pattern
5. Comorbidity view

## Known limitations

- Synthetic data only — findings are illustrative, not epidemiological
  claims about any real population
- `person.race_concept_id` / `ethnicity_concept_id` mapping left as a
  TODO in `models/omop/person.sql` — intentionally not hardcoded since
  it requires a source-to-concept mapping decision
- Vocabulary loading is a manual step (Athena requires an account)
