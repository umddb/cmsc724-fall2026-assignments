# Exercise: Your First PostgreSQL Source Code Change

This exercise walks you through making a small, self-contained change to the PostgreSQL
source code. The goal is to get comfortable with the edit → compile → restart → test loop
before tackling anything more ambitious.

**The change:** make PostgreSQL print a sarcastic notice message every time a client
submits a SELECT query.

---

## Background: How a Query Gets Executed

When you type a query in `psql`, here is the rough path it takes through the server:

```
Client sends SQL string
        │
        ▼
exec_simple_query()          ← src/backend/tcop/postgres.c
        │
        ├─ pg_parse_query()       parse SQL text → raw parse tree (AST)
        ├─ pg_analyze_and_rewrite()  semantic analysis & rewriting
        ├─ pg_plan_queries()         query planning (choose algorithms, indexes, etc.)
        └─ PortalRun()               execution
```

You will add your message right after `pg_parse_query()`, once the server knows what
kind of statement the client sent but before it has done any real work.

---

## Step 1 — Find the Right File and Function

```bash
cd ~/postgres
grep -n "exec_simple_query" src/backend/tcop/postgres.c | head -5
```

Open the file:

```bash
vim src/backend/tcop/postgres.c
```

Search for the function definition (in vim: `/^exec_simple_query`).

The function signature looks like this:

```c
static void
exec_simple_query(const char *query_string)
```

---

## Step 2 — Find the Parse Loop

Inside `exec_simple_query`, scroll down until you see the call to `pg_parse_query`
and the `foreach` loop that follows it:

```c
parsetree_list = pg_parse_query(query_string);
...
foreach(parsetree_item, parsetree_list)
{
    RawStmt    *parsetree = lfirst_node(RawStmt, parsetree_item);
    ...
```

This loop processes each statement in the query string one at a time.
(You can send multiple semicolon-separated statements in a single call; each becomes
one entry in `parsetree_list`.)

A quick way to jump there in vim:

```
/pg_parse_query
```

---

## Step 3 — Add the Sarcastic Message

Add the highlighted lines **at the very top of the foreach loop body**, right after
the `RawStmt *parsetree = ...` line:

```c
foreach(parsetree_item, parsetree_list)
{
    RawStmt    *parsetree = lfirst_node(RawStmt, parsetree_item);

    /* ---------------------------------------------------------------
     * CMSC424 Hello World exercise
     * Check whether this statement is a SELECT, and if so, complain
     * about it before doing any actual work.
     * --------------------------------------------------------------- */
    if (IsA(parsetree->stmt, SelectStmt))
        ereport(NOTICE,
                (errmsg("Oh great, another SELECT. Let me drop everything "
                        "and work on this for you: %s", query_string)));
    /* end CMSC424 exercise */

    /* ... rest of the existing loop body, don't touch it ... */
```

### What each piece does

| Code | Meaning |
|------|---------|
| `IsA(node, SelectStmt)` | Checks the node's tag field; every parse tree node carries a `NodeTag` enum value so you can safely test its type at runtime. |
| `ereport(NOTICE, ...)` | Sends a message back to the client at severity NOTICE (not an error; the query still runs). |
| `errmsg(fmt, ...)` | Printf-style formatter for the message string. |

All the types and macros you need (`SelectStmt`, `IsA`, `ereport`, `NOTICE`, `errmsg`)
are already pulled in by the existing `#include` directives at the top of the file —
no new headers required.

---

## Step 4 — Rebuild

You do **not** need to recompile the entire PostgreSQL tree. Only the backend binary
needs to be rebuilt:

```bash
cd ~/postgres
make -j$(nproc) -C src/backend
make -C src/backend install
```

The first command recompiles only changed files (usually just `postgres.o`), which
takes a few seconds rather than several minutes.

---

## Step 5 — Restart the Server

```bash
pg_ctl restart -D $PGDATA
```

Wait for the "server started" message.

---

## Step 6 — Test It

```bash
psql -U postgres -d university
```

Then run a couple of queries:

```sql
-- This should trigger your message:
SELECT * FROM student LIMIT 3;

-- This should NOT trigger your message (it's not a SELECT):
INSERT INTO student VALUES ('99999', 'Test Student', 'Comp. Sci.', 0);

-- This triggers it again:
SELECT name FROM instructor WHERE salary > 80000;
```

Expected output for the SELECT:

```
NOTICE:  Oh great, another SELECT. Let me drop everything and work on it: SELECT * FROM student LIMIT 3;
 id  |     name      |  dept_name  | tot_cred
-----+---------------+-------------+----------
 ...
```

---

## Exploration Ideas

Once the basic message works, try these variations to dig deeper:

1. **Only complain about `SELECT *`** — Cast `parsetree->stmt` to `SelectStmt *`
   and inspect its `targetList` field. A `SELECT *` has a single `ResTarget` whose
   `val` is a `ColumnRef` with `fields` containing an `A_Star` node.

2. **Count queries in a session** — Declare a `static int select_count = 0;` inside
   the function and increment it on each SELECT, including the count in the message.

3. **Log to the server log instead of the client** — Replace `NOTICE` with `LOG`.
   The message will appear in `$PGDATA/logfile` but not in the psql session.

4. **Intercept at the executor level instead** — Look at `ExecutorStart()` in
   `src/backend/executor/execMain.c`. By that point the query has been planned;
   you can inspect the `PlannedStmt` to get the `commandType` (`CMD_SELECT`,
   `CMD_INSERT`, etc.) without looking at the raw parse tree.

---

## Undoing the Change

When you're done experimenting, revert the file and rebuild:

```bash
cd ~/postgres
git diff src/backend/tcop/postgres.c   # review what you changed
git checkout src/backend/tcop/postgres.c
make -j$(nproc) -C src/backend && make -C src/backend install
pg_ctl restart -D $PGDATA
```
