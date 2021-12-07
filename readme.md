# SQL Server Schema Graph Generator

This is a tool that will create a [Neo4j Graph Database](https://neo4j.com/developer/graph-database/) of [SQL Server](https://www.microsoft.com/en-au/sql-server/sql-server-2019) databases, mapping the objects' inter and intra dependencies.

Whilst Neo4j does have the capability to [import data from SQL server](https://neo4j.com/labs/etl-tool/) directly, it does not represent a dataless schema very well. Especially when a database has been developed with very few Keys.

---
# Setup

1. [Install Neo4j](https://neo4j.com/docs/operations-manual/current/installation/) and configure your first project  
3. [Install Python](https://www.python.org/downloads/)
4. Edit the necessary configuration in the file called `example.env` and rename it to `.env`
5. Run `main.py`
5. Open Neo4j Desktop and query the `sqldependencygraph` database
---
# Examples
### The below examples are produced using Microsoft's `AdventureWorksLT2019` database provided under the [cc-by-sa 4.0](https://creativecommons.org/licenses/by-sa/4.0/) license.

## Example 1 - Schema Dependencies Graph

```cypher
CALL db.schema.visualization()
```
OR
```cypher
CALL apoc.meta.graph()
```

![Screenshot](./blob/Screenshot1.png)

## Example 2 - Object (uspPrintError) Dependencies - Depth 1

```cypher
MATCH (t {name: "uspPrintError"})-[r]-(a) RETURN *
```

![Screenshot](./blob/Screenshot2.png)

## Example 3 - Object (uspPrintError) Dependencies - Depth 3

```cypher
MATCH (t {name: "uspPrintError"})-[r*1..3]-(a) RETURN *
```

![Screenshot](./blob/Screenshot3.png)
---

## Example 4 - Object Dependencies - All

```cypher
MATCH (n) RETURN n
```

![Screenshot](./blob/Screenshot4.png)
---
