/* i feel like this is extra self explanatory */
SELECT s.name as SchemaName
    , o.name as ObjectName
    , CASE o.type_desc 
		WHEN 'SQL_STORED_PROCEDURE' THEN 'stored_procedure'
		WHEN 'USER_TABLE' THEN 'table'
		WHEN 'SQL_TRIGGER' THEN 'trigger'
		WHEN 'SQL_SCALAR_FUNCTION' THEN 'scalar_function'
		WHEN 'SQL_TABLE_VALUED_FUNCTION' THEN 'table_valued_function'
		WHEN 'SQL_INLINE_TABLE_VALUED_FUNCTION' THEN 'table_valued_function'
		WHEN 'VIEW' THEN 'view'
		ELSE 'UNKNOWN'
    END as ObjectType 
FROM sys.objects o
INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE o.type_desc NOT IN (
		'SYSTEM_TABLE',
		'INTERNAL_TABLE',
		'DEFAULT_CONSTRAINT',
		'SERVICE_QUEUE',
		'SYNONYM',
		'UNIQUE_CONSTRAINT',
		'PRIMARY_KEY_CONSTRAINT',
		'FOREIGN_KEY_CONSTRAINT',
		'CHECK_CONSTRAINT'
	)
	AND s.name <> 'sys';