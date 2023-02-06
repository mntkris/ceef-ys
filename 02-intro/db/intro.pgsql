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
-- keeping document pure, no stats, temps, summaries or tracks other than being parts of document itself (ie vat summaries on invoice)
CREATE TABLE intro.IMDocH (
  uid UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  status TEXT NOT NULL DEFAULT 'DRAFT' CHECK(status IN ('DRAFT', 'FINISHED')),
  kind TEXT NOT NULL CHECK(kind IN ('INCM', 'OUTG')),
  number INT,
  signature TEXT,
  date DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE intro.IMDocL (
  uid UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  huid UUID NOT NULL REFERENCES intro.IMDocH(uid),
  item TEXT NOT NULL REFERENCES intro.IMItem(symbol) ON UPDATE CASCADE ON DELETE RESTRICT,
  quantity INT NOT NULL CHECK(quantity>0)
);

-- Evidence
-- connection between document+resources with this evidence
-- some indeopendency (thus redundancy) from document
CREATE TABLE intro.IMStockOps (
  luid UUID NOT NULL REFERENCES intro.IMDocL(uid),
  date DATE NOT NULL,
  item TEXT NOT NULL REFERENCES intro.IMItem(symbol) ON UPDATE CASCADE ON DELETE RESTRICT,
  income INT CHECK(income>0),
  outgoing INT CHECK(outgoing>0)
);

CREATE TABLE intro.IMStock (
  item TEXT NOT NULL REFERENCES intro.IMItem(symbol) ON UPDATE CASCADE ON DELETE RESTRICT,
  stock INT NOT NULL CHECK(stock>0)
);


