# Programming Assignment 2, CMSC724, Fall 2026: PostgreSQL Internals

In this assignment you will explore the internals of PostgreSQL — a production-grade,
open-source relational database system with ~1.4 million lines of C code. Rather than
treating the database as a black box, you will read the source code, trace how a query
moves through the system, and make a real change to the server itself. By the end you
should have a concrete mental model of how a DBMS actually works beneath the SQL surface.

**AI use is highly encouraged for this assignment, for understanding the source code, for identifying the right files to edit, for designing test cases, and for making the code edits. But you should 
review all the code that is generated to ensure it works as expected.**

---

## Getting Started

### Step 1 — Pull the Docker image

```bash
docker pull amolumd/cmsc424-postgres-dev
docker run -it --rm -p 5431:5432 amolumd/cmsc424-postgres-dev
```

This drops you into a bash shell inside the container as the `postgres` user.
PostgreSQL 17 (built from source, with debug symbols and assertions enabled) is already
running, and the `university` database is pre-loaded.

> **Port note:** the container's PostgreSQL listens on 5432 internally, mapped to
> **5431** on your host to avoid conflicts with any local PostgreSQL installation.

> **Note:** `--rm` discards the container, including your source changes, when you exit.
> Either commit your work somewhere outside the container regularly, or drop `--rm` and
> use `docker start -ai <container>` to get back into the same container later.

### Step 2 — Do the Hello World exercise

Before anything else, read through the guided exercise inside the container:

```bash
cat /home/postgres/hello_world_exercise.md
```

It walks you through the edit → compile → restart → test loop so the rest of this
assignment makes sense. It is not graded, but do not skip it.

### Connecting

Inside the container:
```bash
psql -d university          # or just: psql  (alias defaults to -U postgres)
```

From your host machine (with the container running):
```bash
psql -h localhost -p 5431 -U postgres -d university
```

### Rebuild shortcut

After editing any source file, recompile and restart with a single line:

```bash
make -j$(nproc) -C src/backend && make -C src/backend install && pg_ctl restart -D $PGDATA
```

This recompiles only changed files (usually a few seconds) rather than rebuilding
the entire tree.

### Optional: build the image yourself

If you want to modify the Dockerfile or start from scratch, the files are in this directory:

```bash
cd Assignment-2
docker compose build      # takes several minutes — compiles PG17 from source
docker compose run --rm postgres-dev
```

---

## The University Database

The pre-loaded `university` database is the running example from the textbook
(Database System Concepts, Silberschatz, Korth, and Sudarshan).

Schema: `DDL.sql` in this directory (also at `/usr/local/pgsql/sql/DDL.sql` inside the container).
You are welcome to load larger datasets (e.g., the ones from Assignment 1) into the container
if your change needs them.

---

## Programming Challenge

Pick **one** option below and implement it. The options are open-ended; partial credit is
available for serious attempts that don't fully work, as long as your report explains what
you tried, how far you got, and what went wrong.

**You are also free to come up with a fix or change of your own** instead of using one of the
options below — for example, a new plan node or join algorithm, a change to a cost model or
selectivity estimate (e.g., one of the misestimates you saw in Assignment 1), new instrumentation
for some part of the system, or a fix for a behavior of PostgreSQL that you think is wrong.
It should be of similar scope to the options below and involve real changes to the server
code; your report should explain what the change is and why it is interesting.

### Submission format

1. Generate a patch of your changes:
   ```bash
   cd ~/postgres
   git diff > my_change.patch
   ```
2. Write a short report (roughly 2 pages, PDF):
   - What you changed and which files
   - Why the change works (trace through the relevant code path)
   - A screenshot or copy-paste of psql output showing it in action
3. Submit both files on Gradescope.

---

### Option A — Per-query execution statistics

After each query finishes, print a NOTICE showing how many heap pages were read and
how many tuples were scanned, broken down by table. This is a taste of how
`EXPLAIN (ANALYZE, BUFFERS)` works internally. Compare your numbers against
`EXPLAIN (ANALYZE, BUFFERS)` for a few queries and explain any differences.

- Where to look: `pgBufferUsage` (a global struct updated by the buffer manager) in
  `src/include/executor/instrument.h`; snapshot it before and after `PortalRun()` in
  `exec_simple_query` and diff the fields. For the per-table breakdown, look at how
  the scan nodes (e.g., `src/backend/executor/nodeSeqscan.c`) fetch tuples.

### Option B — New executor node: random sampler

Implement a new plan node type `SampleLimit` that works like `LIMIT N` but returns N
randomly selected rows from its child node rather than the first N. This requires:
adding a new `NodeTag`, implementing `ExecSampleLimit` (modeled on `nodeLimit.c`),
wiring it into `execProcnode.c`, and modifying the parser/planner to emit the new
node for a new syntax like `FETCH RANDOM 5 ROWS`.

- Starting point: `src/backend/executor/nodeLimit.c`,
  `src/backend/executor/execProcnode.c`, `src/include/nodes/plannodes.h`
- Hint: reservoir sampling lets you do this in a single pass with O(N) memory.

### Option C — B-tree instrumentation

Modify the B-tree index scan to record how many index pages and how many heap pages
it visits during a single scan, and report this at the end of the query via a NOTICE.
Compare the numbers between a query that uses an index and one that does a seq scan.

- Starting point: `src/backend/access/nbtree/nbtsearch.c` (the scan functions),
  `src/backend/access/nbtree/nbtutils.c`

### Option D — Custom table access method

PostgreSQL 12+ supports pluggable storage engines via the Table Access Method API.
Implement a minimal access method that stores tuples in a simple flat file (no MVCC,
no WAL) — enough to support `INSERT` and `SELECT *`. This is how extensions like
`columnar` or `zedstore` hook into the engine.

- Starting point: `src/backend/access/heap/heapam_handler.c` (the reference
  implementation); `src/include/access/tableam.h` (the interface)

---

## Reference: Key Source Files

| What | File |
|------|------|
| Simple query entry point | `src/backend/tcop/postgres.c` |
| Parser | `src/backend/parser/` |
| Semantic analysis | `src/backend/parser/analyze.c` |
| Query rewriter | `src/backend/rewrite/rewriteHandler.c` |
| Planner top level | `src/backend/optimizer/plan/planner.c` |
| Cost model | `src/backend/optimizer/path/costsize.c` |
| Selectivity estimation | `src/backend/utils/adt/selfuncs.c` |
| Executor dispatch | `src/backend/executor/execProcnode.c` |
| Sequential scan | `src/backend/executor/nodeSeqscan.c` |
| Index scan (B-tree) | `src/backend/access/nbtree/nbtsearch.c` |
| Heap tuple visibility | `src/backend/access/heap/heapam_visibility.c` |
| Error/notice reporting | `src/include/utils/elog.h` |
| Node types & `IsA` macro | `src/include/nodes/nodes.h` |
| Parse tree node structs | `src/include/nodes/parsenodes.h` |
| GUC parameters | `src/backend/utils/misc/guc.c` |
| Built-in text functions | `src/backend/utils/adt/varlena.c` |

---

## Tips

- **`grep -rn "function_name" ~/postgres/src/`** is your best friend for navigating
  the codebase.
- **`git diff`** shows exactly what you've changed at any point.
- **`git stash`** lets you temporarily revert to a clean state to verify your baseline.
- The PostgreSQL source has excellent inline comments — read them. Many directories
  also have a `README` file describing the design (e.g., `src/backend/optimizer/README`,
  `src/backend/access/nbtree/README`).
- If the server crashes after a change (assertion failure, segfault), check
  `$PGDATA/logfile` for the backtrace, then use `gdb` (already installed) to dig in.
- You can always reset to a clean state: `git checkout src/` and rebuild.
