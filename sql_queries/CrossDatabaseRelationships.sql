SET NOCOUNT ON

DROP TABLE IF EXISTS #databases
CREATE TABLE #databases
(
    database_id int NOT NULL,
    database_name sysname NOT NULL
);

/* Setup a list of databases to check, this comes from the `.env` config file */
INSERT INTO #databases
(
    database_id,
    database_name
)
SELECT database_id,
       [name]
FROM sys.databases
WHERE 1 = 1
      AND [state] <> 6
      AND database_id > 4
      AND name IN ({database_list});

DECLARE @database_id int,
        @database_name sysname,
        @sql nvarchar(max);

DROP TABLE IF EXISTS #dependencies
CREATE TABLE #dependencies
(
    referencing_database varchar(max) NOT NULL,
    referencing_schema varchar(max) NOT NULL,
    referencing_object_name varchar(max) NOT NULL,
    referenced_database varchar(max) NOT NULL,
    referenced_schema varchar(max) NOT NULL,
    referenced_object_name varchar(max) NOT NULL,
    referenced_object_type varchar(max) NULL
);

/* get both the intra and inter database dependencies */
WHILE
(SELECT COUNT(*) FROM #databases) > 0
BEGIN
    SELECT TOP (1)
        @database_id = database_id,
        @database_name = database_name
    FROM #databases
    ORDER BY database_name;

    SET @sql
        = 'INSERT INTO #dependencies 
				SELECT  ''' + @database_name + ''', 
						OBJECT_SCHEMA_NAME(d.referencing_id,' + convert(varchar(max), @database_id)
          + '), 
						OBJECT_NAME(d.referencing_id,' + convert(varchar(max), @database_id)
          + '), 
						ISNULL(d.referenced_database_name, ''' + @database_name
          + '''),
						ISNULL(NULLIF(d.referenced_schema_name,''''),''dbo''),
						d.referenced_entity_name,
						NULL
				FROM ' + quotename(@database_name)
          + '.sys.sql_expression_dependencies d
				WHERE d.referenced_database_name in (SELECT database_name FROM #databases)';

    EXEC sys.sp_executesql @Statement = @sql;

    DELETE FROM #databases
    WHERE database_id = @database_id;
END;

DECLARE @referenced_database varchar(max),
        @referenced_schema varchar(max),
        @referenced_object_name varchar(max),
        @object_type varchar(max)

DECLARE dependency_cursor CURSOR LOCAL FORWARD_ONLY READ_ONLY FOR
SELECT referenced_database,
       referenced_schema,
       referenced_object_name
FROM #dependencies

OPEN dependency_cursor
FETCH NEXT FROM dependency_cursor
INTO @referenced_database,
     @referenced_schema,
     @referenced_object_name

/* get the referenced object type, this will be for the relationship name */
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql
        = 'SELECT @object_type = CASE o.type_desc 
						WHEN ''SQL_STORED_PROCEDURE'' THEN ''stored_procedure''
						WHEN ''USER_TABLE'' THEN ''table''
						WHEN ''SQL_TRIGGER'' THEN ''trigger''
						WHEN ''SQL_SCALAR_FUNCTION'' THEN ''scalar_function''
						WHEN ''SQL_TABLE_VALUED_FUNCTION'' THEN ''table_valued_function''
						WHEN ''SQL_INLINE_TABLE_VALUED_FUNCTION'' THEN ''table_valued_function''
						WHEN ''VIEW'' THEN ''view''
						ELSE ''UNKNOWN''
					END
				FROM ' + @referenced_database + '.' + 'sys.objects o
				WHERE o.schema_id = SCHEMA_ID(''' + @referenced_schema + ''') 
					AND o.name = ''' + @referenced_object_name + ''''

    EXEC sys.sp_executesql @Statement = @sql,
                           @param1 = N'@object_type varchar(max) OUTPUT',
                           @object_type = @object_type OUTPUT

    UPDATE #dependencies
    SET referenced_object_type = @object_type
    WHERE referenced_database = @referenced_database
          AND referenced_schema = @referenced_schema
          AND referenced_object_name = @referenced_object_name

    FETCH NEXT FROM dependency_cursor
    INTO @referenced_database,
         @referenced_schema,
         @referenced_object_name
END

CLOSE dependency_cursor
DEALLOCATE dependency_cursor

/* return only the cross database dependencies that are not owned by the sys schema */
SELECT referencing_database,
       referencing_schema,
       referencing_object_name,
       referenced_database,
       referenced_schema,
       referenced_object_name,
       referenced_object_type
FROM #dependencies
WHERE referencing_Database <> referenced_Database
      AND (
              referencing_schema <> 'sys'
              OR referenced_schema <> 'sys'
          )
ORDER BY referenced_object_type;