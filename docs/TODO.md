# Migration scope & progress

> Living document tracking the petgraph → MoonBit migration.

## Goal

Port the Rust **petgraph** library to idiomatic MoonBit: a clear, tested,
reproducible library with CI, README, and design/usage/test documentation.

## Scope

**In scope — ported and tested**

| Area | Contents |
|---|---|
| `graph` | adjacency-list `Graph[N, E]` (directed + undirected), `NodeId`/`EdgeId`/`EdgeRef`, `Direction`, add/remove/find/neighbours/edges, `edge_references`, `edges_connecting`, `map`, `filter_map`, `retain_nodes`, `retain_edges`, `extend_with_edges`, `into_nodes_edges`, `first_edge`/`next_edge`, `from_edges`, `reverse`, `clear` |
| `unionfind` | `UnionFind` with union-by-rank + path compression, incl. the `try_*` family |
| `visit` | `Dfs`, `Bfs`, `DfsPostOrder`, `Topo`, `depth_first_search` + `DfsEvent`; `Walker`/`iter`; view adapters `Reversed`, `NodeFiltered`, `EdgeFiltered`, `UndirectedAdaptor` |
| `algo` — shortest paths | `dijkstra`, `bidirectional_dijkstra`, `astar`, `bellman_ford`, `spfa`, `find_negative_cycle`, `k_shortest_path`, `floyd_warshall`, `johnson` |
| `algo` — order & cycles | `toposort`, `is_cyclic_directed`, `is_cyclic_undirected`, `greedy_feedback_arc_set` |
| `algo` — connectivity | `connected_components`, `kosaraju_scc`, `tarjan_scc`, `condensation`, `articulation_points`, `bridges`, `simple_fast` (+ `Dominators`), `has_path_connecting`, `is_bipartite_undirected` |
| `algo` — trees & flow | `min_spanning_tree` (Kruskal), `min_spanning_tree_prim` (Prim), `steiner_tree`, `ford_fulkerson`, `dinics` |
| `algo` — combinatorial | `greedy_matching`, `maximum_matching` (Gabow's blossom), `maximal_cliques`, `dsatur_coloring`, `all_simple_paths`, `all_simple_paths_multi`, `dag_to_toposorted_adjacency_list`, `dag_transitive_reduction_closure` |
| `dot` | Graphviz DOT export with the five upstream `Config` flags |

**Out of scope**

- Alternative representations: `StableGraph`, `GraphMap`, `MatrixGraph`, `Csr`,
  `adj::List`, and the `Acyclic` / `Frozen` wrappers.
- Parsers: petgraph's DOT parser and graph6 encoder/decoder. This port emits
  DOT but does not read it.
- `serde` serialization, `quickcheck` integration, the `Ix` memory-size generic.
- Isomorphism (VF2), `page_rank`, and `parallel_johnson` (no threads).

## Design decisions

- Drop Rust's `Ix`/`Ty` type params: index type fixed to `Int`; directedness is a
  `Directedness` enum field on the graph (not a marker trait).
- `NodeId`/`EdgeId` are wrapper structs (type safety) deriving `Eq, Hash, Compare, Debug`.
- Two trait families instead of petgraph's 18-trait hierarchy:
  `NeighborSource` (graph → neighbours; `pub(open)` so other packages and
  downstream users can implement it) and `Measure` / `BoundedMeasure` (weight
  arithmetic).
- Algorithms take a concrete `Graph[N, E]` + an `edge_cost` closure where weights matter.
- Priority queue: `@priority_queue` from core with a reversed-`Compare` `MinScored`.

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
- [x] **P1a graph** — core types, mutators (incl. swap-remove fix-ups), neighbours, builders, `NeighborSource`.
- [x] **P1b unionfind** — full port + tests.
- [x] **P2a visit** — VisitMap + Dfs/Bfs/DfsPostOrder/Topo + depth_first_search.
- [x] **P2b dot** — DOT renderer + escaping + snapshot tests.
- [x] **P3 algo (core)** — measure trait + dijkstra/astar/bellman_ford, toposort/cycles/components, Kosaraju & Tarjan SCC, Kruskal MST.
- [x] **P4 integration** — `cmd/main` demo, doc-tested `README.mbt.md`, design/usage/test docs, GitHub Actions CI, `.mbti` frozen, fmt + multi-backend green.
- [x] **P5 test fidelity** — ported petgraph's own in-scope test cases (`*_ported_test.mbt`, original Rust names preserved), with a documented out-of-scope skip list (测试文档 §9).
- [x] **P6 breadth** — toolchain upgrade to moonc 0.10.7; `BoundedMeasure`; the
      remaining shortest-path, connectivity, flow, tree and combinatorial
      algorithms; the `Graph` transform/edge-reference API; the `@visit` view
      adapters. Two pre-existing correctness defects found and fixed in the
      process (see below).

**Current state: 328 tests passing on all four backends — wasm / wasm-gc / js /
native. `moon check --deny-warn --target all` clean, `moon test --deny-warn`
clean, `moon fmt` and `moon info` idempotent. ~7.1k lines of implementation and
~8.2k lines of tests.**

## Defects found and fixed

1. **Undirected traversal in `dijkstra` / `astar` / `bellman_ford`.** All three
   walked `edges_directed(node, Outgoing)` and then read the edge's stored
   `dst` as the neighbour. An undirected edge stored as `(other, node)`
   therefore sent the search back into `node`, so reachable nodes were silently
   reported unreachable. Fixed by walking `Graph::edges(node)`, which
   normalizes endpoints. Regression suite:
   `src/algo/undirected_regression_test.mbt`.
2. **`dinics` non-termination.** Looped forever when `source == destination`
   (upstream petgraph has the same defect). Now returns zero flow. Regression
   suite: `src/algo/flow_degenerate_test.mbt`.

## Known follow-ups

- Consolidate three inlined shortest-path routines (`johnson`,
  `steiner_tree`'s `steiner_shortest_paths`, `kosaraju_scc`'s manual reverse
  pass) — see `DESIGN.md` §7.
- Expose `floyd_warshall_path` (the predecessor-matrix variant) so
  `steiner_tree` can drop its private copy.
- Unify the two edge-list walkers in `neighbors.mbt` and `edge_refs.mbt` behind
  one private routine.
- `Measure` / `BoundedMeasure` are instantiated for `Int` and `Double` only.

## Validation commands

```
moon check --target all --deny-warn
moon fmt && git diff --exit-code
moon info && git diff --exit-code
moon test --deny-warn
moon test --target wasm|wasm-gc|js|native
moon run src/cmd/main
moon test --enable-coverage && moon coverage report -f summary
```

## Source-of-truth mapping (Rust → MoonBit)

| Rust file | MoonBit package |
|-----------|-----------------|
| `crates/petgraph/src/graph_impl/mod.rs` | `src/graph/` |
| `crates/petgraph/src/unionfind.rs` | `src/unionfind/` |
| `crates/petgraph/src/visit/traversal.rs`, `dfsvisit.rs`, `reversed.rs`, `filter.rs`, `undirected_adaptor.rs` | `src/visit/` |
| `crates/petgraph/src/algo/*.rs` | `src/algo/` |
| `crates/petgraph/src/dot/mod.rs` | `src/dot/` |
