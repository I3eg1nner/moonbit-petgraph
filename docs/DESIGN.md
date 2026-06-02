# Design Document — petgraph for MoonBit

This document explains the architecture of the MoonBit port of [petgraph](https://github.com/petgraph/petgraph),
the design decisions taken to adapt Rust idioms to MoonBit, and the rationale behind them.

## 1. Goals & non-goals

**Goals**

- Provide a clear, idiomatic MoonBit graph library covering the most-used parts of petgraph.
- Faithful semantics: where we port an algorithm, results match petgraph's.
- Fully tested, CI-verified, reproducible, and documented.

**Non-goals (out of scope for this port)**

- The alternative graph representations `StableGraph`, `GraphMap`, `Csr`, `MatrixGraph`.
- Advanced algorithms: max-flow, isomorphism (VF2), general matching (blossom),
  page-rank, all-pairs (floyd_warshall/johnson), dominators, etc.
- Serialization (serde), quickcheck integration, the `Ix` memory-size generic.

## 2. Package architecture

The module `moonbit-community/petgraph` (source dir `src/`) is split into cohesive packages:

| Package | Path | Responsibility | Depends on |
|---------|------|----------------|------------|
| `graph` | `src/graph` | Core adjacency-list `Graph[N, E]`, ids, directions, the `NeighborSource` trait | — |
| `unionfind` | `src/unionfind` | Disjoint-set `UnionFind` | — |
| `visit` | `src/visit` | Traversals: `Dfs`, `Bfs`, `DfsPostOrder`, `Topo`, `depth_first_search` | `graph` |
| `dot` | `src/dot` | Graphviz DOT export | `graph` |
| `algo` | `src/algo` | Shortest paths, SCC, MST, toposort, cycles, components | `graph`, `visit`, `unionfind` |
| `petgraph` (root) | `src/` | Convenience re-exports / prelude | all |
| `main` (demo) | `src/cmd/main` | Runnable example | `graph`, `algo`, `dot` |

Dependency graph (acyclic):

```
unionfind  (leaf)        graph (leaf)
                            |
              +-------------+-------------+
              |             |             |
            visit          dot          (algo also uses unionfind)
              |                           |
              +------------ algo ---------+
                            |
                  root prelude  ->  cmd/main demo
```

`graph` and `unionfind` are leaves and were implemented in parallel; `visit` and `dot`
only need `graph`. This mirrors petgraph's `crates/core` (foundational types) vs
`crates/petgraph` (algorithms) split, flattened into one MoonBit module.

## 3. Adapting Rust to MoonBit

petgraph's `Graph<N, E, Ty = Directed, Ix = u32>` carries two extra type parameters that
MoonBit cannot express ergonomically. We dropped both:

### 3.1 The `Ix` index-size parameter → fixed `Int`

In Rust, `Ix` lets you pick `u8`/`u16`/`u32` to shrink a node index for memory. MoonBit's
`Int` is 32-bit, exactly matching petgraph's `u32` default and covering every realistic
graph. We therefore fix indices to `Int` and expose them through wrapper types.

### 3.2 The `Ty` directedness parameter → a runtime enum field

petgraph uses a zero-sized marker type (`Directed`/`Undirected`) and the `EdgeType` trait
for *static* dispatch. MoonBit has no zero-sized-type dispatch, and petgraph reads
`is_directed()` at runtime anyway (only `neighbors_directed` and `find_edge` branch on it).
So directedness is a plain field:

```moonbit
pub enum Directedness { Directed; Undirected }
// Graph[N, E] { nodes; edges; mut ty : Directedness }
```

`Graph::new()` builds a directed graph, `Graph::new_undirected()` an undirected one.

### 3.3 Typed indices: wrapper structs, not aliases

```moonbit
pub struct NodeId(Int) derive(Eq, Hash, Compare, Show)
pub struct EdgeId(Int) derive(Eq, Hash, Compare, Show)
```

A bare `Int` alias would let node and edge indices mix silently — a real bug class in graph
code. The wrappers cost essentially nothing and give distinct `Show`/`Hash`. petgraph's
`IndexType::max()` "end of list" sentinel becomes a reserved constant with `is_end()`.

### 3.4 Intrusive edge lists

The heart of petgraph is preserved: each node stores the heads of two singly-linked edge
lists (outgoing / incoming); each edge stores the next pointers for both directions and its
two endpoints. The Rust `[EdgeIndex; 2]` / `[NodeIndex; 2]` arrays become two named mutable
fields plus a `next(dir)/set_next(dir, …)` helper so direction-indexed code (notably
`change_edge_links`) ports almost line-for-line.

```moonbit
struct Node[N] { mut weight : N; mut next_out : EdgeId; mut next_in : EdgeId }
struct Edge[E] { mut weight : E; mut next_out : EdgeId; mut next_in : EdgeId
                 mut src : NodeId; mut dst : NodeId }
```

`add_edge` is O(1) list-prepend; **`remove_node`/`remove_edge` use swap-remove plus a
link fix-up (`change_edge_links`)** — the single trickiest part of the port, covered by
white-box invariant tests.

### 3.5 Ownership / borrowing

MoonBit has no borrow checker, so petgraph's `index_twice` / `Pair::One|Both` trick (needed
to mutably borrow two `Vec` slots at once) collapses to direct array reads/writes, with an
explicit `a == b` self-loop branch. This is *simpler* in MoonBit, not harder.

## 4. The light trait layer

Rather than reproduce petgraph's deep trait hierarchy (`GraphBase`, `GraphRef`, `Visitable`,
`IntoNeighbors`, `IntoEdges`, …), we introduce exactly two small traits:

- **`NeighborSource`** (in `graph`): the minimal "graph that yields neighbours + node ids".
  ```moonbit
  pub trait NeighborSource {
    node_count(Self) -> Int
    node_ids(Self) -> Iter[NodeId]
    neighbors_directed(Self, NodeId, Direction) -> Iter[NodeId]
  }
  ```
  Implemented for `Graph[N, E]` for all `N, E`. Consumed by the traversals and the structural
  algorithms (`is_cyclic_directed`, `connected_components`, `kosaraju_scc`, `tarjan_scc`).
  Reversed traversal (needed by Kosaraju) is just `neighbors_directed(n, dir.opposite())` —
  no `Reversed` adaptor type.

- **`Measure`** (in `algo`): weight arithmetic for shortest-path / MST algorithms.
  ```moonbit
  pub trait Measure : Compare + Add { zero() -> Self }
  // impl Measure for Int, Double
  ```
  MoonBit traits cannot say "any number", so we enumerate `Int` and `Double` instances.

Everything else operates on the concrete `Graph[N, E]` plus an `edge_cost` closure where
weights matter — mirroring petgraph's `edge_cost: FnMut` parameter. This keeps weight
generics out of the graph type and matches "concrete + a light trait" design choice.

## 5. Algorithms & their building blocks

| Algorithm | Technique | Key dependency |
|-----------|-----------|----------------|
| `dijkstra` | binary heap + visited map | `@priority_queue`, `Measure` |
| `astar` | heap + heuristic | reuses dijkstra's `MinScored` |
| `bellman_ford` | edge relaxation, negative-cycle detection | `Measure` |
| `toposort` | Kahn / DFS via `Topo` | `visit` |
| `is_cyclic_directed` | DFS back-edge | `visit` |
| `is_cyclic_undirected` | union of edges | `unionfind` |
| `connected_components` | union of edges | `unionfind` |
| `kosaraju_scc` | two DFS passes (fwd + reversed) | `NeighborSource` |
| `tarjan_scc` | single DFS, lowlink | `NeighborSource` |
| `min_spanning_tree` | Kruskal (sort edges + union) | `unionfind`, `Measure` |

**Priority queue.** `@priority_queue` from `moonbitlang/core` is a max-heap keyed by
`Compare`. We define `MinScored(K, NodeId)` with a reversed `Compare` so the heap pops the
smallest cost — exactly petgraph's `scored::MinScored` trick.

## 6. Testing strategy

See `docs/TESTING.md`. In brief: black-box `*_test.mbt` for every public API (using petgraph
as the behavioural oracle), white-box `*_wbtest.mbt` for the intrusive-edge-list invariants
and union-find internals, snapshot tests for DOT output, and property-style cross-checks
(e.g. dijkstra ≤ bellman_ford on non-negative graphs; component count vs SCC count).

## 7. Known limitations / future work

- No `StableGraph`/`GraphMap`/`Csr`/`MatrixGraph` yet.
- Neighbour / node / edge iteration returns a lazy `Iter[_]` (idiomatic MoonBit; each accessor
  call yields a fresh single-use iterator). Algorithms needing random access or repeated passes
  over one node's neighbours materialise locally with `.to_array()` (e.g. iterative `tarjan_scc`).
- `Measure` is instantiated for `Int`/`Double` only.
