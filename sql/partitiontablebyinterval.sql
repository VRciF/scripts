-- Function: partitiontablebyinterval()

-- DROP FUNCTION partitiontablebyinterval();

CREATE OR REPLACE FUNCTION partitiontablebyinterval()
  RETURNS trigger AS
$BODY$
DECLARE
    period text;
    periodformat text;
    newtable text;
    createtable text;
    intervalinseconds int8;
    currentyearinterval float;
    currentyearipos float;
    tablebeginperiod timestamp with time zone;
    tableendperiod timestamp with time zone;
    insertdate timestamp with time zone;
    r RECORD;
    primarycols text;
    partitioncolumn text;
    execinsert text;
BEGIN
-- check if trigger is called correctly on AFTER INSERT
    IF (TG_OP != 'INSERT' OR TG_WHEN != 'AFTER') THEN
        RAISE EXCEPTION 'trigger ''%'' is only allowed on INSERT AFTER statements', TG_NAME;
    END IF;
-- check if at least the interval argument is given
    IF (TG_NARGS<1) THEN
        RAISE EXCEPTION 'missing interval argument';
    END IF;
    partitioncolumn := 'created';
-- check if partitioncolumn is given
    IF (TG_NARGS>=2) THEN
        partitioncolumn := TG_ARGV[1];
    END IF;

-- calculate in which timeframe we're in AND format the timestamp more human readable
    EXECUTE ' SELECT (' || quote_literal(NEW) || '::' || TG_RELID::regclass || ').'||partitioncolumn||' as idate' INTO r;
    --EXECUTE 'SELECT '||partitioncolumn||' as someval FROM (SELECT $1.*) as src' INTO r USING NEW;
    insertdate := r.idate;

    intervalinseconds := EXTRACT(EPOCH FROM date_trunc('second', TG_ARGV[0]::interval))::int8;
    currentyearinterval := EXTRACT(EPOCH FROM date_trunc('second', insertdate-date_trunc('year', insertdate)));
    currentyearipos := (currentyearinterval::int8 / intervalinseconds);
    tablebeginperiod := date_trunc('year', insertdate)+(currentyearipos*TG_ARGV[0]::interval);
    tableendperiod := tablebeginperiod+TG_ARGV[0]::interval;

    IF (NOT (tablebeginperiod<=insertdate AND insertdate<=tableendperiod)) THEN
        tablebeginperiod := tablebeginperiod-TG_ARGV[0]::interval;
        tableendperiod := tableendperiod-TG_ARGV[0]::interval;
    END IF;

    IF (to_char(date_trunc('second', TG_ARGV[0]::interval), 'SS')::int4>0) THEN
        periodformat := 'YYYYMMDD_HH24MISS';
        tablebeginperiod := date_trunc('second', tablebeginperiod);
        tableendperiod := date_trunc('second', tableendperiod);
    ELSIF (to_char(date_trunc('minute', TG_ARGV[0]::interval), 'MI')::int4>0) THEN
        periodformat := 'YYYYMMDD_HH24MI';
        tablebeginperiod := date_trunc('minute', tablebeginperiod);
        tableendperiod := date_trunc('minute', tableendperiod);
    ELSIF (to_char(date_trunc('hour', TG_ARGV[0]::interval), 'HH24')::int4>0) THEN
        periodformat := 'YYYYMMDD_HH24';
        tablebeginperiod := date_trunc('hour', tablebeginperiod);
        tableendperiod := date_trunc('hour', tableendperiod);
    ELSIF (to_char(date_trunc('day', TG_ARGV[0]::interval), 'DD')::int4>0) THEN
        periodformat := 'YYYYMMDD';
        tablebeginperiod := date_trunc('day', tablebeginperiod);
        tableendperiod := date_trunc('day', tableendperiod);
    ELSIF (to_char(date_trunc('month', TG_ARGV[0]::interval), 'MM')::int4>0) THEN
        periodformat := 'YYYYMM';
        tablebeginperiod := date_trunc('month', tablebeginperiod);
        tableendperiod := date_trunc('month', tableendperiod);
    ELSE
        periodformat := 'YYYY';
        tablebeginperiod := date_trunc('year', tablebeginperiod);
        tableendperiod := date_trunc('year', tableendperiod);
    END IF;

    period := to_char(tablebeginperiod, periodformat);

    newtable := TG_TABLE_SCHEMA||'.'||TG_TABLE_NAME||'_'||period;

-- insert the new row into the the new table
    execinsert := 'INSERT INTO '||newtable||' SELECT * FROM '||TG_TABLE_SCHEMA||'.'||TG_TABLE_NAME||' WHERE id=' || NEW.id || ';';
    BEGIN
        EXECUTE execinsert;
    EXCEPTION WHEN OTHERS THEN
        BEGIN

-- if an exception is thrown i assume the new table doesnt exist yet, so we create it now

-- first get a list of primary key columns
-- this is used to provide a unique primary key over all partitioned tables
        primarycols := '';
        FOR r IN EXECUTE('SELECT
      pg_attribute.attname,
      format_type(pg_attribute.atttypid, pg_attribute.atttypmod)
    FROM pg_index, pg_class, pg_attribute
    WHERE
      pg_class.oid = '''||TG_TABLE_SCHEMA||'.'||TG_TABLE_NAME||'''::regclass AND
      indrelid = pg_class.oid AND
      pg_attribute.attrelid = pg_class.oid AND
      pg_attribute.attnum = any(pg_index.indkey)
      AND indisprimary' ) LOOP
        IF (LENGTH(primarycols)>0) THEN primarycols := ','||primarycols; END IF;
        primarycols := primarycols||r.attname;
        END LOOP;

-- now create the 'create table' statement using check constraint and inheritance including the primary keys which have been found
        createtable := 'CREATE TABLE '||newtable||' (CHECK ( '||partitioncolumn||'>= '''||tablebeginperiod||''' AND '||partitioncolumn||'<  '''||tableendperiod||''' )';
        IF(LENGTH(primarycols)>0) THEN createtable := createtable||' ,PRIMARY KEY('||primarycols||') '; END IF;
        createtable := createtable||') INHERITS('||TG_TABLE_SCHEMA||'.'||TG_TABLE_NAME||');';

-- finally create the new partition-table
            EXECUTE createtable;

-- using pg_get_indexdef ill create a CREATE INDEX statement for the new table to copy index definition from parent table
-- code is partly from: http://vibhork.blogspot.com/2010/12/rebuilding-pkey-and-indexes-without.html
-- thx to Vibhor Kumar for sharing
-- note: im not using CONCURRENTLY cause the new table is surely empty and thus create index will be a bit faster
    for r in SELECT c2.relname as indexname,
       substring(pg_catalog.pg_get_indexdef(i.indexrelid, 0, true),0,
            position( 'ON 'in pg_catalog.pg_get_indexdef(i.indexrelid, 0, true))-1)
       ||'_'||period||' ON '||newtable||' '||
       substring(pg_catalog.pg_get_indexdef(i.indexrelid, 0, true),
            position( 'USING 'in pg_catalog.pg_get_indexdef(i.indexrelid, 0, true)))
       ||';'
       AS command
       FROM pg_catalog.pg_class c, pg_catalog.pg_class c2, pg_catalog.pg_index i
WHERE c.oid=TG_RELID  AND c.oid = i.indrelid AND i.indexrelid = c2.oid
and i. indisprimary=false ORDER BY i.indisprimary DESC, i.indisunique DESC, c2.relname
    LOOP
-- create index
       EXECUTE r.command;
    END LOOP;

-- this exception for duplicate table is used cause im not sure
-- if its possible that independent transactions interfere each other during create table
--      so im not sure if there could be a race condition during 2 transactions inserting and thus try to create the new table
--      thats why im using DUPLICATE_TABLE, just to be on the safe side and no insert will can be lost
--  on the other side if this would be possible a primary key using bigserial could also have such problems which in fact dont exist,
--    maybe im too overcautious
        EXCEPTION WHEN DUPLICATE_TABLE THEN END;

-- finally insert the new row again
        EXECUTE execinsert;
    END;

-- since were in the INSERT AFTER trigger i can safely delete the old row from ONLY the trigger table
    EXECUTE 'DELETE FROM ONLY '||TG_TABLE_SCHEMA||'.'||TG_TABLE_NAME||' WHERE id='||NEW.id;

    RETURN NULL;
END;
$BODY$
  LANGUAGE plpgsql;
