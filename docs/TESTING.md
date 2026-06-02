# Testing Document — petgraph for MoonBit

This document describes how the port is tested, how to run the tests, and what each test
layer guarantees. petgraph (Rust) is used as the **behavioural oracle**: ported algorithms
are expected to produce the same results as the originals.

## How to run

```bash
export PATH="$HOME/.moon/bin:$PATH"   # if moon is not already on PATH

moon test                 # run all tests (default wasm-gc backend)
moon test --target all    # run on every backend (wasm-gc, js, native)
moon test src/graph       # run only one package's tests
moon test --enable-coverage && moon coverage report -f summary   # coverage
```

CI (`.github/workflows/ci.yml`) runs format-check, multi-backend type-check, build & test on
`wasm-gc`/`js`/`native`, and a coverage report on every push and pull request.

## Test layers

### 1. Black-box tests (`*_test.mbt`)

Exercise only the public API of a package, the way a user would. Every public function has at
least one black-box test. Examples:

- `graph`: construction, `add_node`/`add_edge`, counts, `find_edge` (directed & undirected),
  neighbour order, `externals`, `from_edges`, `reverse`.
- `unionfind`: disjointness, `union`/`same_set`, labelling.
- `visit`: traversal orders for `Dfs`/`Bfs`/`DfsPostOrder`/`Topo` on known graphs.
- `algo`: shortest-path costs, toposort order, SCC partitions, MST edge sets, component counts.
- `dot`: rendered DOT strings.

Assertions use `inspect(value, content=…)` / `@json.inspect`. Snapshot content is seeded with
`moon test --update` and then **verified by hand against petgraph semantics** — we never blindly
accept generated output.

### 2. White-box tests (`*_wbtest.mbt`)

Reach into package internals to assert representation invariants that the public API cannot
observe directly:

- `graph`: after every `remove_node`/`remove_edge` (which use swap-remove + link fix-ups), the
  intrusive edge lists stay consistent — every node's `next_out`/`next_in` chain terminates at
  the end sentinel, no `EdgeId` dangles, and each edge's `src`/`dst` match its position in the
  adjacency lists. Tested across multiple removal orderings, self-loops, and last-element removal.
- `unionfind`: parent/rank arrays after path compression and union-by-rank.

### 3. Snapshot tests for DOT

DOT output is compared against golden strings taken from petgraph's own `dot` test module, so
formatting (directed `->` vs undirected `--`, escaping, node/edge labels) matches exactly.

### 4. Property-style cross-checks

Deterministic generated graphs (a small LCG seed, no external quickcheck dependency) validate
invariants that should hold for *any* input:

- `add_edge` then `remove_edge` round-trips `edge_count`.
- On a random DAG, `toposort` output respects every edge (source precedes target).
- On non-negative graphs, `dijkstra` distances equal `bellman_ford` distances.
- On an undirected graph, `connected_components` equals the number of SCCs of its symmetric
  directed closure.

### 5. Documentation tests

`README.mbt.md` (symlinked to `README.md`) carries the canonical end-to-end example as a
compiled, executed test, so the README cannot drift from the real API.

## Determinism notes

Neighbour iteration follows petgraph's **reverse-insertion order** (intrusive list prepend).
Tests that compare neighbour/traversal sequences either expect that exact order or sort first.
SCC partitions and component representatives are sorted before being inspected so output is
stable across runs and backends.

## Current status

**133 tests pass** on all three backends (`wasm-gc`, `js`, `native`), and
`moon check --deny-warn --target all` is clean. Of these, **58 are ported
faithfully from petgraph's own test suite** (in `*_ported_test.mbt` files, keeping
the original Rust test names — see the Chinese `测试文档.md` §9 for the full
correspondence and the documented out-of-scope skip list). Per-package counts:

| Package | Tests | of which ported | Notes |
|---------|------:|----:|-------|
| `graph` | 33 | 13 | edge-list invariant white-box tests + ported core tests |
| `unionfind` | 24 | 10 | full port of petgraph `tests/unionfind.rs` |
| `visit` | 17 | 6 | traversal orders, cycle skipping, DFS events |
| `dot` | 13 | 5 | snapshot tests vs. petgraph golden strings |
| `algo` | 43 | 24 | shortest paths, SCC, MST, toposort + cross-checks |
| root (`README.mbt.md`) | 3 | 0 | doc-tested usage examples |

The 58 ported tests passed with **no implementation changes**, validating
behavioural fidelity to petgraph. Line coverage is ~90% (850/942); the untested
remainder is mostly the `cmd/main` demo and a few defensive branches. Reproduce
locally:

```bash
moon test --enable-coverage && moon coverage report -f summary
```

See `docs/TODO.md` for per-phase progress.
