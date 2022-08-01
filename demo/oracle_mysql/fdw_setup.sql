-- install extensions
CREATE SCHEMA mysql_fdw;
CREATE EXTENSION mysql_fdw SCHEMA mysql_fdw;

CREATE SCHEMA oracle_fdw;
CREATE EXTENSION oracle_fdw SCHEMA oracle_fdw;

-- create foreign servers
CREATE SERVER oracle FOREIGN DATA WRAPPER oracle_fdw OPTIONS (dbserver '//oracle:1521/xepdb1');
CREATE USER MAPPING FOR postgres SERVER oracle OPTIONS (user 'test', password 'test');
CREATE SCHEMA oracle;

CREATE SERVER mysql FOREIGN DATA WRAPPER mysql_fdw OPTIONS (host 'mysql', port '3306');
CREATE USER MAPPING FOR postgres SERVER mysql OPTIONS (username 'test', password 'test');
CREATE SCHEMA mysql;

-- import foreign schemas after corresponding databases completed initialization within theirs container
CREATE SCHEMA admin;
CREATE OR REPLACE FUNCTION admin.import_foreign_schema
( p_foreign_schema   VARCHAR
, p_local_schema     VARCHAR
, p_foreign_server   VARCHAR
, p_steps            INTEGER DEFAULT 36
, p_sleep            INTEGER DEFAULT 5
)
RETURNS void
AS
$import_foreign_schema$
DECLARE
   idx   INTEGER;
BEGIN
   RAISE INFO USING message = CONCAT_WS(' ',
      'Importing foreign schema', QUOTE_LITERAL(p_foreign_schema),
      'from server', QUOTE_LITERAL(p_foreign_server),
      'into local schema', QUOTE_LITERAL(p_local_schema)
   );

   FOR idx IN 1..p_steps
   LOOP
      BEGIN
         EXECUTE CONCAT_WS(' ',
            'import foreign schema', QUOTE_IDENT(p_foreign_schema),
            'from server', QUOTE_IDENT(p_foreign_server),
            'into', QUOTE_IDENT(p_local_schema)
         );
         RAISE INFO USING message = 'Schema ' || QUOTE_LITERAL(p_foreign_schema) || ' succesfully imported';
         EXIT;
      EXCEPTION
         WHEN OTHERS THEN
            RAISE WARNING USING message = CONCAT('error code: ', sqlstate, ', message: ', sqlerrm);
            RAISE WARNING USING message = 'Error happened. sleeping for ' || p_sleep || ' seconds...';
            PERFORM pg_sleep(p_sleep);
      END;
   END LOOP;
END;
$import_foreign_schema$
LANGUAGE plpgsql;

SELECT admin.import_foreign_schema('dev', 'mysql', 'mysql');
SELECT admin.import_foreign_schema('TEST', 'oracle', 'oracle');
