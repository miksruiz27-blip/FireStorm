-- F4 source audit: rows without a traceable source stay in the DB but are hidden from the UI and the fit.
ALTER TABLE experiments ADD COLUMN IF NOT EXISTS is_verified boolean NOT NULL DEFAULT true;
ALTER TABLE test_points ADD COLUMN IF NOT EXISTS is_verified boolean NOT NULL DEFAULT true;
