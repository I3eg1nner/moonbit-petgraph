# Migration TODO & Progress Tracker

> Living document tracking the petgraph → MoonBit migration. Updated as phases complete.

## Goal

Port the core of the Rust **petgraph** library to idiomatic MoonBit: a clear, tested,
reproducible library with CI, README, and design/usage/test documentation.

## Scope (agreed)

- **In scope (focused core):**
  - `graph` — adjacency-list `Graph[N, E]` (directed + undirected), `NodeId`/`EdgeId`,
    `Direction`, add/remove/find/neighbors/edges, `from_edges`, `reverse`, `clear`.
  - `unionfind` — `UnionFind` with union-by-rank + path compression.
  - `visit` — `Dfs`, `Bfs`, `DfsPostOrder`, `Topo`, `depth_first_search` + `DfsEvent`.
  - `algo` — `dijkstra`, `astar`, `bellman_ford`, `toposort`, `is_cyclic_directed`,
    `is_cyclic_undirected`, `connected_components`, `kosaraju_scc`, `tarjan_scc`,
    `min_spanning_tree` (Kruskal).
  - `dot` — Graphviz DOT export.
- **Out of scope:** StableGraph, GraphMap, CSR, MatrixGraph, max-flow, isomorphism,
  matching, page_rank, and other advanced algorithms.

## Design decisions

- Drop Rust's `Ix`/`Ty` type params: index type fixed to `Int`; directedness is a
  `Directedness` enum field on the graph (not a marker trait).
- `NodeId`/`EdgeId` are wrapper structs (type safety) deriving `Eq, Hash, Compare, Show`.
- Two light traits only: `NeighborSource` (graph → neighbors, used by traversals &
  structural algos) and `Measure` (weight arithmetic for shortest-path/MST).
- Algorithms take a concrete `Graph[N, E]` + an `edge_cost` closure where weights matter.
- Priority queue: use `@priority_queue` from core with a reversed-`Compare` `MinScored`.

## Package layout & dependency graph

```
unionfind  (leaf)        graph (leaf)
                            |
              +-------------+-------------+
              |             |             |
            visit          dot          (algo also uses unionfind)
              |                           |
              +------------ algo ---------+
                            |
              prelude (root re-export)  ->  cmd/main demo
```

## Phases

- [x] **P0 Scaffold** — module + package configs, CI skeleton, docs skeleton.
- [x] **P1a graph** — core types, mutators (incl. swap-remove fix-ups), neighbors, builders, `NeighborSource`. **34 tests pass.**
- [x] **P1b unionfind** — full port + tests. **14 tests pass.**
- [x] **P2a visit** — VisitMap + Dfs/Bfs/DfsPostOrder/Topo + depth_first_search. **11 tests.**
- [x] **P2b dot** — DOT renderer + escaping + snapshot tests. **8 tests.**
- [x] **P3 algo** — measure trait + dijkstra/astar/bellman_ford, toposort/cycles/components, kosaraju & tarjan SCC, MST. **19 tests** (incl. cross-checks).
- [x] **P4 integration** — `cmd/main` demo, doc-tested `README.mbt.md` (3 tests), design/usage/test docs, GitHub Actions CI, `.mbti` frozen, fmt + multi-backend green.

- [x] **P5 test fidelity** — ported 58 of petgraph's own in-scope test cases (`*_ported_test.mbt`, original Rust names preserved), with a documented out-of-scope skip list (测试文档 §9). No implementation bugs surfaced.

**Result: 133 tests passing on wasm-gc/js/native (75 self-authored + 58 ported from petgraph); `moon check --deny-warn --target all` clean; ~90% line coverage (850/942).**

> **Toolchain convention (enforced):** This MoonBit build deprecates `Show` for debugging.
> Use `derive(Debug)` (not `Show`) on custom types and `debug_inspect(...)` (not `inspect`) in
> tests. `moon fmt` migrates configs to the new `moon.mod`/`moon.pkg` format (no `warn-list`).
- [ ] **P3 algo** — measure trait, then dijkstra→astar→bellman_ford, toposort/cycles/components, scc, MST.
- [ ] **P4 integration** — prelude re-exports, cmd/main demo, README.mbt.md, design/usage/test docs, CI green, coverage.

## Key risks (carry forward)

1. **swap_remove index invalidation** in `remove_node`/`remove_edge` — port `change_edge_links` literally; guard with white-box edge-list invariant tests.
2. **Priority queue direction** — `@priority_queue` is max-heap by `Compare`; `MinScored` must reverse.
3. **Neighbor ordering** is reverse-insertion (intrusive prepend) — match petgraph's expected orders in golden tests or sort before comparing.
4. **Self-loop double-count** in undirected neighbor walk — keep the `skip_start` guard.
5. **Numeric generics** — enumerate `impl Measure for Int/Double`; no "any number" trait.

## Validation commands

```
moon fmt --check
moon check --target all
moon build
moon test
moon coverage analyze   # coverage report
moon info               # regenerate .mbti
```

## Source-of-truth mapping (Rust → MoonBit)

| Rust file | MoonBit package |
|-----------|-----------------|
| `crates/petgraph/src/graph_impl/mod.rs` | `src/graph/` |
| `crates/petgraph/src/unionfind.rs` | `src/unionfind/` |
| `crates/petgraph/src/visit/traversal.rs`, `dfsvisit.rs` | `src/visit/` |
| `crates/petgraph/src/algo/*.rs` | `src/algo/` |
| `crates/petgraph/src/dot/mod.rs` | `src/dot/` |
