-- Team drop: required design modifications per experiment + its research group (experiment_classifier classes).
ALTER TABLE experiments ADD COLUMN modifications text[] NOT NULL DEFAULT '{}';
ALTER TABLE experiments ADD COLUMN research_group text NOT NULL DEFAULT '';
