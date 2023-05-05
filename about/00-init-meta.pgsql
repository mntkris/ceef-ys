DROP SCHEMA IF EXISTS meta CASCADE;
CREATE SCHEMA meta;

CREATE TYPE meta.Sep AS ENUM('->');

CREATE TYPE meta.DefineReturn AS (
  ddl text, code text
);

CREATE OR REPLACE FUNCTION meta.DefineReturn(
  ddl text, code text DEFAULT ''::text
) RETURNS meta.DefineReturn AS $BODY$
  SELECT ddl, code;
$BODY$ LANGUAGE SQL IMMUTABLE;

-- ==================================================

CREATE OR REPLACE FUNCTION meta.define_scalar(
  schema text, name text, systemtype text
) RETURNS text AS
$BODY$
#variable_conflict use_variable
BEGIN
  schema = coalesce(lower(schema), CURRENT_SCHEMA);
  name = lower(name);

  RETURN format('CREATE DOMAIN %I.%I AS %s;', schema, name, systemtype);
END;
$BODY$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION meta.define_scalar(
  name text, systemtype text
) RETURNS text AS
$BODY$
BEGIN
  RETURN meta.define_scalar(NULL, name, systemtype);
END;
$BODY$ LANGUAGE plpgsql;

-- ==================================================

CREATE VIEW meta.EnumAttrsV AS
  SELECT n.nspname schema, t.typname name, 
    e.enumlabel label, e.enumsortorder position
  FROM pg_catalog.pg_type t 
    JOIN pg_catalog.pg_enum e on t.oid = e.enumtypid  
    JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace;

CREATE OR REPLACE FUNCTION meta.define_enum(
  schema text, name text, sep meta.Sep, VARIADIC items text[]
) RETURNS meta.DefineReturn AS 
$BODY$
#variable_conflict use_variable
DECLARE
  currentitems text[];
  ret text;
BEGIN
  schema = coalesce(lower(schema), CURRENT_SCHEMA);
  name = lower(name);

  SELECT array_agg(ea.label ORDER BY ea.position) INTO currentitems
  FROM meta.EnumAttrsV ea
  WHERE (ea.schema, ea.name) = (schema, name);

  IF currentitems IS NULL THEN
    RETURN meta.DefineReturn(
      format($$CREATE TYPE %I.%I AS ENUM ('%s');$$, schema, name, array_to_string(items, $$','$$)));
  END IF;

  IF currentitems = items THEN
    RETURN NULL;
  END IF;

  IF cardinality(currentitems) = cardinality(items) AND currentitems != items THEN
    --warn its only rename not reposition if some pairs of item labels are swapped
    RETURN meta.DefineReturn(
      string_agg(format('ALTER TYPE %I.%I RENAME VALUE %L TO %L;', schema, name, currentitem, item), E'\n'))
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

	RETURN meta.Definereturn(ret);
	
END;
$BODY$ LANGUAGE plpgsql;

-- ==================================================

CREATE VIEW meta.CompositeAttrsV AS                       
  SELECT tn.nspname schema, t.typname type, an.nspname aschema, at.typname atype, a.attname aname, 
    an.nspname IN ('pg_catalog', 'information_schema') asystemtype
  FROM pg_catalog.pg_type t
  JOIN pg_catalog.pg_namespace tn ON t.typnamespace = tn.oid
  JOIN pg_catalog.pg_class c ON t.typrelid = c.oid AND c.relkind = 'c'
  JOIN pg_catalog.pg_attribute a ON t.typrelid = a.attrelid AND a.attnum > 0 AND NOT a.attisdropped
  JOIN pg_catalog.pg_type at ON a.atttypid = at.oid
  JOIN pg_catalog.pg_namespace an ON at.typnamespace = an.oid;
 
CREATE TYPE meta.CompositeAttr AS (
  name text, schema text, type text
);

CREATE FUNCTION meta.define_composite(
  schema text, name text, sep meta.Sep, VARIADIC attrs meta.CompositeAttr[]
) RETURNS meta.DefineReturn AS 
$BODY$
#variable_conflict use_variable
DECLARE
BEGIN
END;
$BODY$ LANGUAGE plpgsql;
