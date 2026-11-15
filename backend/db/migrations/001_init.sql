-- float8 (not numeric): pg returns numeric as strings and would break the contract.
CREATE TABLE habitats (
  id text PRIMARY KEY,
  name text NOT NULL,
  o2_pct float8 NOT NULL,
  pressure_psia float8 NOT NULL,
  gravity_g float8 NOT NULL,
  source text NOT NULL
);

CREATE TABLE experiments (
  id text PRIMARY KEY,
  name text NOT NULL,
  platform text NOT NULL,
  fuel_type text NOT NULL CHECK (fuel_type IN ('solid', 'liquid', 'gas')),
  domain text[] NOT NULL,
  hardware text NOT NULL,
  o2_range float8[] NOT NULL,
  pressure_kpa_range float8[] NOT NULL,
  gravity text NOT NULL DEFAULT 'micro',
  flow_cm_s_range float8[] NOT NULL,
  materials text[] NOT NULL DEFAULT '{}',
  key_findings text[] NOT NULL DEFAULT '{}',
  sources jsonb NOT NULL CHECK (jsonb_array_length(sources) > 0),
  search tsvector -- set by the seed upsert: name + materials + key_findings
);
CREATE INDEX experiments_search ON experiments USING gin (search);

CREATE TABLE test_points (
  id serial PRIMARY KEY,
  experiment_id text NOT NULL REFERENCES experiments (id) ON DELETE CASCADE,
  material text NOT NULL,
  o2_pct float8 NOT NULL,
  pressure_kpa float8 NOT NULL,
  gravity_g float8 NOT NULL,
  flow_cm_s float8,
  outcome text NOT NULL CHECK (outcome IN ('burn', 'extinct')),
  spread_rate_mm_s float8,
  source text NOT NULL,
  UNIQUE NULLS NOT DISTINCT (experiment_id, material, o2_pct, pressure_kpa, gravity_g, flow_cm_s)
);

CREATE TABLE material_moc (
  material text NOT NULL,
  pressure_kpa float8 NOT NULL,
  moc_pct float8 NOT NULL,
  source text NOT NULL,
  PRIMARY KEY (material, pressure_kpa)
);
