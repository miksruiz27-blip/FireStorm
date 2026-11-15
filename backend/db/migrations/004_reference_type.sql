-- F5: standards and reference documents are citable but are not investigations (never ranked).
ALTER TABLE experiments ADD COLUMN IF NOT EXISTS type text NOT NULL DEFAULT 'investigation'
  CHECK (type IN ('investigation', 'reference'));
