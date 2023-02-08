DROP SCHEMA IF EXISTS intro CASCADE;
CREATE SCHEMA intro;

/*
three main players: resource document evidence
look at draft below, having little erp experience it should be obvious
*/

-- Resource
CREATE TABLE intro.IMItem (
  uid UUID NOT NULL DEFAULT gen_random_uuid(),
  symbol TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL
);

-- Document
-- keeping document pure, no stats, temps, summaries or tracks 
--   other than being parts of document itself (ie vat summaries on invoice)
CREATE TABLE intro.IMDocH (
  uid UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  status TEXT NOT NULL DEFAULT 'DRAFT' CHECK(status IN ('DRAFT', 'FINISHED')),
  type TEXT NOT NULL CHECK(type IN ('INCM', 'OUTG')),
  number INT,
  signature TEXT,
  date DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE intro.IMDocL (
  uid UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  huid UUID NOT NULL REFERENCES intro.IMDocH(uid),
  item TEXT NOT NULL REFERENCES intro.IMItem(symbol) 
    ON UPDATE CASCADE ON DELETE RESTRICT,
  quantity INT NOT NULL CHECK(quantity>0)
);

-- Evidence
-- connection between document+resources with this evidence
-- some indeopendency (thus redundancy) from document
-- all needed fields to build stock from stockops
CREATE TABLE intro.IMStockOps (
  huid UUID NOT NULL REFERENCES intro.IMDocH(uid),
  luid UUID NOT NULL REFERENCES intro.IMDocL(uid) PRIMARY KEY,
  date DATE NOT NULL,
  item TEXT NOT NULL REFERENCES intro.IMItem(symbol)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  income INT NOT NULL CHECK(income >= 0),
  outgoing INT NOT NULL CHECK(outgoing >= 0)
);

CREATE TABLE intro.IMStock (
  item TEXT NOT NULL PRIMARY KEY REFERENCES intro.IMItem(symbol)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  stock INT NOT NULL CHECK(stock > 0)
);

CREATE OR REPLACE PROCEDURE intro.imdoc_finish(huid UUID) 
LANGUAGE PLPGSQL
AS $BODY$
#variable_conflict use_variable
BEGIN
  -- TODO number and signature

  INSERT INTO intro.IMStockOps(huid, luid, date, item, income, outgoing)
  SELECT h.uid, l.uid, h.date, l.item, 
    CASE WHEN h.type = 'INCM' THEN l.quantity ELSE 0 END,
    CASE WHEN h.type = 'OUTG' THEN l.quantity ELSE 0 END
  FROM intro.IMDocH h JOIN intro.IMDocL l ON l.huid = h.uid
  WHERE h.uid = huid;

END;
$BODY$;

CREATE OR REPLACE FUNCTION intro.imstock_registerops_trig() RETURNS TRIGGER 
LANGUAGE PLPGSQL
AS $BODY$
#variable_conflict use_variable
BEGIN

  WITH delta AS (
    SELECT item, SUM(i.income - i.outgoing) quantity
    FROM inserted i GROUP BY item)
  MERGE INTO intro.IMStock AS s
  USING delta d ON s.item = d.item
  WHEN NOT MATCHED  THEN
    INSERT VALUES(d.item, d.quantity)
  WHEN MATCHED AND s.stock + d.quantity > 0 THEN
    UPDATE SET stock = s.stock + d.quantity
  WHEN MATCHED THEN
    DELETE;

  RETURN NULL;
END;
$BODY$;

CREATE OR REPLACE TRIGGER IMStock_insert AFTER INSERT ON intro.IMStockOps
  REFERENCING NEW TABLE AS inserted 
  FOR EACH STATEMENT EXECUTE FUNCTION intro.imstock_registerops_trig();

-- sample
INSERT INTO intro.IMItem(symbol, name) 
SELECT 'item-' || n, 'ITEM ' || n
FROM generate_series(1,9) n;

INSERT INTO intro.IMDocH(type, number) 
SELECT 'INCM', -n FROM generate_series(1, 9) n
UNION ALL
SELECT 'OUTG', -n FROM generate_series(1, 9) n;

INSERT INTO intro.IMDocL(huid, item, quantity)
SELECT h.uid, i.symbol, -h.number * 2
FROM intro.IMDocH h, intro.IMItem i WHERE type = 'INCM'
UNION ALL
SELECT h.uid, i.symbol, -h.number
FROM intro.IMDocH h, intro.IMItem i WHERE type = 'OUTG';

INSERT INTO intro.IMItem(symbol, name)
VALUES('item-0', 'ITEM 0');

INSERT INTO intro.IMDocH(type, number)
VALUES('INCM', 0),('OUTG', 0);

INSERT INTO intro.IMDocL(huid, item, quantity)
SELECT h.uid, 'item-0', 42
FROM intro.IMDocH h WHERE h.number = 0;

DO $$
DECLARE
  huid UUID;
BEGIN
  FOR huid IN SELECT uid FROM intro.IMDocH ORDER BY type LOOP
    raise notice '%', (select h from intro.imdoch h where uid=huid);
    raise notice '%', array(select s from intro.imstock s);
    CALL intro.imdoc_finish(huid);
  END LOOP;
END; $$;

/*
select * from intro.imitem;
select * from intro.imdoch;
select * from intro.imdocl;
select item, sum(income), sum(outgoing) from intro.imstockops group by item ordwer by item;
select * from intro.imstock order by item;
*/




/*

TODO
- numbers and signatures
- rls for not edit finished docs
- -------------------------------
- domains
- doctype, subplayer config
- indices
- named constraints + error messages
- document stats sample
-

next
03-more-intro
- sale invoice order
- purchase invoice order
- composite types (ie parts by area/module in resource)
- inhertiance on resource and document
- flow on statyses, validation
- identification refining and parametrization of building blocks 
- idempotent definition on building blocks, automatic incremental ddls
-
-

*/
