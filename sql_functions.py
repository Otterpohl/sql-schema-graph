import pyodbc
from loguru import logger
from neo4j import GraphDatabase
from pathlib import Path


def create_object_nodes(session, cursor, database):
    logger.info("Creating object nodes and relationships to schema")

    query = read_sql_file('Objects')
    dependencies = cursor.execute(query)

    # "Upsert" a new sql object and add some metadata
    for dependency in dependencies:
        query = 'MERGE (n:{objectType} {{database: "{database}", \
            schema: "{schemaName}", name: "{objectName}"}})' .format(
            objectType=dependency.ObjectType,
            objectName=dependency.ObjectName,
            database=database,
            schemaName=dependency.SchemaName
        )

        logger.debug(
            "Creating [{ObjectType}] node [{schemaName}].[{ObjectName}]",
            ObjectName=dependency.ObjectName,
            schemaName=dependency.SchemaName,
            ObjectType=dependency.ObjectType
        )
        logger.trace(query)

        session.run(query)


def create_object_relationships(session, cursor):
    logger.info("Creating object dependencies")

    query = read_sql_file('ObjectDependencies')
    dependencies = cursor.execute(query)

    # Create relationships depending on referenced object type
    for dependency in dependencies:
        query = """MATCH (a:{ReferencedEntityType}),(b:{ReferencingEntityType})
                   WHERE a.name = '{ObjectName}'
                       AND b.name = '{ReferencingEntityName}'
                   CREATE (a)<-[r:depends_on_{ReferencedEntityType}]-(b)
                   RETURN r""".format(
            ObjectName=dependency.ObjectName,
            ReferencingEntityName=dependency.ReferencingEntityName,
            ReferencingEntityType=dependency.ReferencingEntityType,
            ReferencedEntityType=dependency.ReferencedEntityType
        )

        logger.debug(
            "Creating dependency => [{ReferencingEntityName}]\
({ReferencingEntityType}) -> \
[{ObjectName}]({ReferencedEntityType})",
            ObjectName=dependency.ObjectName,
            ReferencingEntityName=dependency.ReferencingEntityName,
            ReferencingEntityType=dependency.ReferencingEntityType,
            ReferencedEntityType=dependency.ReferencedEntityType
        )
        logger.trace(query)

        session.run(query)


def create_key_relationships(session, cursor):
    logger.info("Create table key relationships")

    query = read_sql_file('KeyRelationships')
    keys = cursor.execute(query)

    # Create relationships depending on table keys
    for key in keys:
        query = """MATCH (a:Table),(b:Table)
                   WHERE a.name = '{PK_Table}' AND b.name = '{FK_Table}'
                   CREATE (a)<-[r:Key_Relationship {{name: 'PK:{PK_Column} \
                       <-> FK:{FK_Column}'}}]-(b)
                   RETURN r""".format(
            PK_Table=key.PK_Table,
            FK_Table=key.FK_Table,
            PK_Column=key.PK_Column,
            FK_Column=key.FK_Column
        )

        logger.debug(
            "Creating Key relationship => [{FK_Table}]({FK_Column}) \
-> [{PK_Table}]({PK_Column})",
            PK_Table=key.PK_Table,
            FK_Table=key.FK_Table,
            PK_Column=key.PK_Column,
            FK_Column=key.FK_Column
        )
        logger.trace(query)

        session.run(query)


def create_neo4j_database(session, database):
    # Create or replace neo4j database... obviously...
    query = "CREATE OR REPLACE DATABASE {database}".format(database=database)

    logger.info("Recreating database => [{}]", database)
    logger.trace(query)

    session.run(query)


def read_sql_file(fileName) -> str:
    # Get the content of a sql query file
    path = Path(__file__).parent /\
        "./sql_queries/{fileName}.sql".format(fileName=fileName)
    file = open(path)
    data = file.read()
    file.close()

    return data


def create_cross_database_relationships(session, cursor):
    logger.info("Creating cross database relationships")

    query = read_sql_file('CrossDatabaseRelationships')
    dependencies = cursor.execute(query)

    # Create relationships between databases depending on referenced object type
    for dependency in dependencies:
        query = """MATCH (a),(b)
                   WHERE (  a.name      = '{referenced_object}'
                            AND a.database  = '{referenced_database}'
                            AND a.schema    = '{referenced_schema}'
                        ) AND (
                            b.name      = '{referencing_object}'
                            AND b.database  = '{referencing_database}'
                            AND b.schema    = '{referencing_schema}'
                        )
                   CREATE (a)<-[r:depends_on_{referenced_object_type}]-(b)
                   RETURN r""".format(
            referencing_object=dependency.referencing_object_name,
            referenced_object=dependency.referenced_object_name,
            referencing_database=dependency.referencing_database.lower(),
            referenced_database=dependency.referenced_database.lower(),
            referencing_schema=dependency.referencing_schema,
            referenced_schema=dependency.referenced_schema,
            referenced_object_type=dependency.referenced_object_type
        )

        logger.debug(
            "Creating dependency => [{referencing_database}].\
[{referencing_schema}].[{referencing_object}] \
-> [{referenced_database}].[{referenced_schema}]\
.[{referenced_object}]",
            referenced_database=dependency.referenced_database.lower(),
            referenced_schema=dependency.referenced_schema,
            referenced_object=dependency.referenced_object_name,
            referencing_database=dependency.referencing_database.lower(),
            referencing_schema=dependency.referencing_schema,
            referencing_object=dependency.referencing_object_name
        )
        logger.trace(query)

        session.run(query)


def main():
    # Create neo4j session
    logger.info("Creating Neo4j session")
    uri = "neo4j://localhost:7687"
    driver = GraphDatabase.driver(uri, auth=("neo4j", "admin"))
    neo4jSession = driver.session()

    # Create neo4j database
    neo4jDatabase = "sqldependencygraph"
    create_neo4j_database(neo4jSession, neo4jDatabase)

    # Create neo4j Session
    neo4jSession = driver.session(database=neo4jDatabase)

    # List of SQL Server databases to map
    databases = ["AdventureWorksLT2019", ]

    # Create the object, dependency and key relationships within the database
    for database in databases:
        logger.info("Processing database => {}", database)

        # Create SQL Server session for this Database
        sqlConnectionString = "Driver={{SQL Server}}; Server=.; Database=\
{database}; Trusted_Connection=yes;".format(database=database)
        sqlSession = pyodbc.connect(sqlConnectionString)
        sqlCursor = sqlSession.cursor()

        create_object_nodes(neo4jSession, sqlCursor, database)
        create_object_relationships(neo4jSession, sqlCursor)
        create_key_relationships(neo4jSession, sqlCursor)

    # Create SQL Server session for any Database really, this time its master
    sqlConnectionString = "Driver={{SQL Server}}; Server=.; Database=\
{database}; Trusted_Connection=yes;".format(database="master")
    sqlSession = pyodbc.connect(sqlConnectionString)
    sqlCursor = sqlSession.cursor()

    # Create relationships between databases
    create_cross_database_relationships(neo4jSession, sqlCursor)

    # Cleanup sessions
    sqlSession.close()
    driver.close()
