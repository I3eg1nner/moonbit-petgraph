# Testing Document — petgraph for MoonBit

This document describes how the port is tested, how to run the tests, and what each test
layer guarantees. petgraph (Rust) is used as the **behavioural oracle**: ported algorithms
are expected to produce the same results as the originals.

## How to run

```bash
export PATH="$HOME/.moon/bin:$PATH"   # if moon is not already on PATH

moon test                 # run all tests (default wasm-gc backend)
moon test --target all    # run on every backend (wasm, wasm-gc, js, native)
moon test src/graph       # run only one package's tests
moon test --enable-coverage && moon coverage report -f summary   # coverage
```

CI (`.github/workflows/ci.yml`) runs, on every push and pull request:
`moon check --target all --deny-warn`; `moon fmt` and `moon info` followed by
`git diff --exit-code` (so formatting and the committed `.mbti` interfaces
cannot drift); `moon test --deny-warn`; a build-and-test matrix over all four
backends (`wasm`, `wasm-gc`, `js`, `native`); a `moon run src/cmd/main` smoke
job so the entry point the README documents is verified to run; and a coverage
report.

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

### 5. Regression tests for fixed defects

Each defect found in the port gets a dedicated suite that fails on the old
behaviour, so it cannot silently return:

- `algo/undirected_regression_test.mbt` — every fixture stores its undirected
  edges "backwards" (higher index as source), which is the exact shape that
  broke `dijkstra` / `astar` / `bellman_ford`. Also covers undirected symmetry
  and self-loops.
- `algo/flow_degenerate_test.mbt` — `source == destination` (which used to hang
  `dinics`) and unreachable sinks, asserted for both max-flow algorithms.

### 6. Documentation tests

`src/README.mbt.md` carries the README's examples as compiled, executed tests.
It is **generated** from the root `README.md` (same file minus the CI badge and
the language-switcher line), so the examples a reader sees and the examples the
test runner executes are byte-identical and cannot drift. Public algorithm,
traversal and unionfind entry points additionally carry runnable ```` ```mbt check ````
doc-test examples in their doc comments; bare ```` ``` ```` fences are *not*
compiled or run.

## Determinism notes

Neighbour iteration follows petgraph's **reverse-insertion order** (intrusive list prepend).
Tests that compare neighbour/traversal sequences either expect that exact order or sort first.
SCC partitions and component representatives are sorted before being inspected so output is
stable across runs and backends.

## Current status

**331 tests pass** on all four backends (`wasm`, `wasm-gc`, `js`, `native`), and
`moon check --deny-warn --target all` is clean. Roughly 161 of them are ported
from petgraph's own test suite, keeping the original Rust test names — see the
Chinese `测试文档.md` §9 for the full correspondence and the documented
out-of-scope skip list. Per-package counts:

| Package | Tests | Notes |
|---------|------:|-------|
| `graph` | 50 | edge-list invariant white-box tests, transform/retain invariants, ported core tests |
| `unionfind` | 27 | full port of petgraph `tests/unionfind.rs` + doc-test examples |
| `visit` | 43 | traversal orders, DFS events, view adapters, `Walker` iterators |
| `dot` | 13 | snapshot tests vs. petgraph golden strings |
| `algo` | 192 | shortest paths, connectivity, flow, matching, trees, cross-checks, regressions |
| root | 6 | doc-tested README examples + `version()` |

Line coverage is **2311/2471 ≈ 93.5%**; the untested remainder is mostly the
`cmd/main` demo and defensive branches. Reproduce locally:

```bash
moon test --enable-coverage && moon coverage report -f summary
```

### What the tests actually caught

The first round of the port had all 58 then-ported tests pass with no
implementation changes, which was read as evidence of fidelity. Widening the
surface showed that reading was too optimistic — two real defects surfaced
immediately:

1. `dijkstra` / `astar` / `bellman_ford` traversed undirected graphs
   incorrectly, silently reporting reachable nodes as unreachable. The original
   tests missed it because their undirected fixtures happened to store every
   edge in the direction the buggy code read.
2. `dinics` did not terminate when `source == destination`.

Both now have dedicated regression suites (layer 5 above). The lesson recorded
here for future work: a fixture that only exercises the convenient orientation
of an undirected edge proves very little.

See `docs/TODO.md` for per-phase progress.
