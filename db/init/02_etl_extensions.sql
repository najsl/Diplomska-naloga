-- ETL schema, load_batch control table, municipality_name_mapping
-- Run after 01_init.sql

CREATE SCHEMA IF NOT EXISTS etl;

-- Load batch control table for traceability
CREATE TABLE IF NOT EXISTS etl.load_batch (
    batch_id      SERIAL PRIMARY KEY,
    loaded_at     TIMESTAMPTZ DEFAULT NOW(),
    source_table  TEXT,
    row_count     INTEGER
);

-- Municipality name mapping: admin_unit_name from accidents -> municipality_id
-- Used when LOWER(TRIM(name_sl)) does not match admin_unit_name (diacritics, "občina" vs "Občina", etc.)
CREATE TABLE IF NOT EXISTS core.municipality_name_mapping (
    admin_unit_name   TEXT NOT NULL,
    municipality_id   INTEGER NOT NULL REFERENCES core.dim_municipality(municipality_id),
    PRIMARY KEY (admin_unit_name)
);

CREATE INDEX IF NOT EXISTS idx_munic_name_mapping_admin
    ON core.municipality_name_mapping (admin_unit_name);
