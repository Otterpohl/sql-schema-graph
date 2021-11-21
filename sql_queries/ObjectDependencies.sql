/* get all objects dependent on other object, self referenced are filtered out */
SELECT o.name as ObjectName 
    , CASE o.type_desc 
                WHEN 'SQL_STORED_PROCEDURE' THEN 'stored_procedure'
                WHEN 'USER_TABLE' THEN 'table'
                WHEN 'SQL_TRIGGER' THEN 'trigger'
                WHEN 'SQL_SCALAR_FUNCTION' THEN 'scalar_function'
                WHEN 'SQL_TABLE_VALUED_FUNCTION' THEN 'table_valued_function'
                WHEN 'SQL_INLINE_TABLE_VALUED_FUNCTION' THEN 'table_valued_function'
                WHEN 'VIEW' THEN 'view'
				ELSE 'UNKNOWN'
            END as ReferencedEntityType
	, d.referencing_entity_name as ReferencingEntityName
    , CASE o1.type_desc
                WHEN 'SQL_STORED_PROCEDURE' THEN 'stored_procedure'
                WHEN 'USER_TABLE' THEN 'table'
                WHEN 'SQL_TRIGGER' THEN 'trigger'
                WHEN 'SQL_SCALAR_FUNCTION' THEN 'scalar_function'
                WHEN 'SQL_TABLE_VALUED_FUNCTION' THEN 'table_valued_function'
                WHEN 'SQL_INLINE_TABLE_VALUED_FUNCTION' THEN 'table_valued_function'
                WHEN 'VIEW' THEN 'view'
				ELSE 'UNKNOWN'
            END as ReferencingEntityType
FROM sys.objects o
INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
CROSS APPLY sys.dm_sql_referencing_entities (s.name + '.' + o.name,'OBJECT') d
INNER JOIN sys.objects o1 ON d.referencing_id = o1.object_id
WHERE d.referencing_entity_name NOT LIKE 'CK%'
    AND o.name <> d.referencing_entity_name;