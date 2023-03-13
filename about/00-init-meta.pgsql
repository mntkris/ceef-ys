DROP SCHEMA IF EXISTS meta CASCADE;
CREATE SCHEMA meta;

CREATE TYPE meta.Sep AS ENUM('->');

CREATE OR REPLACE FUNCTION meta.define_enum(
  schema text, name text, sep meta.Sep, VARIADIC items text[]
) RETURNS text AS 
$BODY$
#variable_conflict use_variable
DECLARE
  currentitems text[];
  ret text;
BEGIN
  schema = coalesce(lower(schema), CURRENT_SCHEMA);
  name = lower(name);

  --https://stackoverflow.com/questions/9540681/list-postgres-enum-type
  SELECT array_agg(e.enumlabel ORDER BY e.enumsortorder) INTO currentitems
  FROM pg_type t 
    JOIN pg_enum e on t.oid = e.enumtypid  
    JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
  WHERE n.nspname = schema AND t.typname = name;
  IF currentitems IS NULL THEN
    RETURN format(
      $$CREATE TYPE %I.%I AS ENUM ('%s');$$, schema, name,
      array_to_string(items, $$','$$));
  END IF;

  IF cardinality(currentitems) = cardinality(items) AND currentitems != items THEN
    --warn its only rename not reposition if some pairs of item labels are swapped
    RETURN string_agg(format('ALTER TYPE %I.%I RENAME VALUE %L TO %L;', schema, name, currentitem, item), E'\n')
    FROM UNNEST(currentitems, items) x(currentitem, item)
    WHERE currentitem != item;
  END IF;

  IF NOT items @> currentitems THEN
    RAISE EXCEPTION 'REMOVING VALUES IS NOT IMPLEMENTED HERE';
  END IF;

  IF EXISTS(
    WITH o AS (
      SELECT * FROM unnest(currentitems) WITH ORDINALITY o(item, ord)),
    n AS (
      SELECT * FROM unnest(items) WITH ORDINALITY n(item, ord)),
    ver AS (
      SELECT o.ord ord, row_number() OVER(ORDER BY n.ord) rn FROM n JOIN o ON n.item = o.item)
    SELECT 1 FROM ver WHERE ord != rn)
  THEN
    RAISE EXCEPTION 'CHANGING THE ORDER OF ITEMS IS NOT IMPLEMENTED HERE';
  END IF;

  WITH o AS (
    SELECT * FROM unnest(currentitems) o(item)),
  n AS (
    SELECT * FROM unnest(items) WITH ORDINALITY n(item, ord)),
  r AS (
    SELECT n.ord, n.item nitem, o.item oitem, 
      lead(n.item,1) OVER(ORDER BY n.ord) nextitem
    FROM n LEFT JOIN o ON n.item = o.item)
  SELECT string_agg(
    CASE WHEN nextitem IS NOT NULL THEN
      format('ALTER TYPE %I.%I ADD VALUE %L BEFORE %L;', schema, name, nitem, nextitem) ELSE
      format('ALTER TYPE %I.%I ADD VALUE %L;', schema, name, nitem)
    END, E'\n' ORDER BY ord DESC) INTO ret
  FROM r WHERE oitem IS NULL;
	RETURN ret;
	
END;
$BODY$ LANGUAGE plpgsql;

/*
DROP TYPE IF EXISTS testenum;
DO $$ 
DECLARE 
  cmd TEXT = '';
BEGIN
--                                             '0','1','2','3','4','5','6','7','8','9'
cmd = meta.define_enum(NULL, 'testenum', '->',     'X',        'Y',            '8'    ); EXECUTE cmd; RAISE info '%', cmd;
cmd = meta.define_enum(NULL, 'testenum', '->',     '1',        '4',            '8'    ); EXECUTE cmd; RAISE info '%', cmd;
cmd = meta.define_enum(NULL, 'testenum', '->',     '1','2',    '4',    '6',    '8'    ); EXECUTE cmd; RAISE info '%', cmd;
--cmd = meta.define_enum(null, 'testenum', '->',   '2','1','3','4',    '6',    '8'    ); EXECUTE cmd; RAISE info '%', cmd;  -- error
cmd = meta.define_enum(NULL, 'testenum', '->',     '1','2','3','4',    '6',    '8'    ); EXECUTE cmd; RAISE info '%', cmd;
cmd = meta.define_enum(NULL, 'testenum', '->',     '1','2','3','4',    '6','7','8','9'); EXECUTE cmd; RAISE info '%', cmd;
cmd = meta.define_enum(NULL, 'testenum', '->',     '1','2','3','4','5','6','7','8','9'); EXECUTE cmd; RAISE info '%', cmd;
END; $$;
SELECT n.nspname as enum_schema, t.typname as enum_name, 
  --e.enumsortorder as enum_sortorder, e.enumlabel as enum_value
  ARRAY_AGG(e.enumlabel ORDER BY e.enumsortorder)
FROM pg_type t 
  JOIN pg_enum e on t.oid = e.enumtypid  
  JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'o' AND t.typname = 'testenum'
GROUP BY n.nspname, t.typname;
*/