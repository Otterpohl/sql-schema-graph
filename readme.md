# Neo4j

This is a tool that will create a [Neo4j Graph Database](https://neo4j.com/developer/graph-database/) of [SQL Server](https://www.microsoft.com/en-au/sql-server/sql-server-2019) databases, mapping the objects inter and intra dependencies.

Whilst Neo4j does have the capability to [import data from SQL server](https://neo4j.com/labs/etl-tool/) directly, it does not represent a dataless schema very well. Especially when a database has been developed with very few table Key relationships.

---
# Setup

1. [Install](https://neo4j.com/docs/operations-manual/current/installation/) Neo4j Desktop
2. [Install](https://www.python.org/downloads/) Python
3. Run python script
    ```python
    python -m main.py
    ```

---
# Examples
### The below examples are produced using Microsoft's `AdventureWorksLT2019` database provided under the [cc-by-sa 4.0](https://creativecommons.org/licenses/by-sa/4.0/) license.

## Example 1 - Schema Dependencies Graph

```cypher
call db.schema.visualization()
```

![Screenshot](./blob/screenshot1.png)

## Example 2 - Object (uspPrintError) Dependencies - Depth 1

```cypher
MATCH (t {name: "uspPrintError"})-[r]-(a) RETURN *
```

![Screenshot](./blob/screenshot2.png)

## Example 3 - Object Dependencies - Depth 2

```cypher
MATCH (t {name: "uspPrintError"})-[r*1..3]-(a) RETURN *
```

![Screenshot](./blob/screenshot3.png)
---