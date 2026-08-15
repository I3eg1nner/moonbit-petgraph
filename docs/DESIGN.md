# Design Document — petgraph for MoonBit

This document explains the architecture of the MoonBit port of [petgraph](https://github.com/petgraph/petgraph),
the design decisions taken to adapt Rust idioms to MoonBit, and the rationale behind them.

## 1. Goals & non-goals

**Goals**

- Provide a clear, idiomatic MoonBit graph library covering the most-used parts of petgraph.
- Faithful semantics: where we port an algorithm, results match petgraph's.
- Fully tested, CI-verified, reproducible, and documented.

**Non-goals (out of scope for this port)**

- The alternative graph representations `StableGraph`, `GraphMap`, `Csr`,
  `MatrixGraph`, `adj::List`, and the `Acyclic` / `Frozen` wrappers. Everything
  is built on the one adjacency-list `Graph[N, E]`.
- Parsing: petgraph's DOT parser and its graph6 encoder/decoder. This port
  *emits* DOT but does not read it.
- Serialization (serde), quickcheck integration, the `Ix` memory-size generic.
- Isomorphism (VF2), page-rank, and `parallel_johnson` (no threads in this
  port).

Note that several things listed here as non-goals in earlier revisions have
since been ported and are no longer excluded: max-flow (Ford–Fulkerson and
Dinic's), general matching (Gabow's blossom algorithm), all-pairs shortest
paths (Floyd–Warshall and Johnson), and dominators.

## 2. Package architecture

The module `I3eg1nner/petgraph` (source dir `src/`) is split into cohesive packages:

| Package | Path | Responsibility | Depends on |
|---------|------|----------------|------------|
| `graph` | `src/graph` | Core adjacency-list `Graph[N, E]`, ids, directions, the `NeighborSource` trait | — |
| `unionfind` | `src/unionfind` | Disjoint-set `UnionFind` | — |
| `visit` | `src/visit` | Traversals (`Dfs`, `Bfs`, `DfsPostOrder`, `Topo`, `depth_first_search`), the `Walker` iterator layer, and the `Reversed` / `NodeFiltered` / `EdgeFiltered` / `UndirectedAdaptor` view adapters | `graph` |
| `dot` | `src/dot` | Graphviz DOT export | `graph` |
| `algo` | `src/algo` | 35 algorithms: shortest paths (single-source and all-pairs), connectivity, dominators, spanning and Steiner trees, max-flow, matching, colouring, clique and path enumeration, DAG reduction | `graph`, `visit`, `unionfind` |
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
pub struct NodeId(Int) derive(Eq, Hash, Compare, Debug)
pub struct EdgeId(Int) derive(Eq, Hash, Compare, Debug)
```

A bare `Int` alias would let node and edge indices mix silently — a real bug class in graph
code. The wrappers cost essentially nothing and give distinct `Debug`/`Hash`. petgraph's
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
  pub(open) trait NeighborSource {
    node_count(Self) -> Int
    node_ids(Self) -> Iter[NodeId]
    neighbors_directed(Self, NodeId, Direction) -> Iter[NodeId]
  }
  ```
  Implemented for `Graph[N, E]` for all `N, E`. Consumed by the traversals and the structural
  algorithms (`is_cyclic_directed`, `connected_components`, `kosaraju_scc`, `tarjan_scc`,
  `articulation_points`, `has_path_connecting`, `is_bipartite_undirected`, `simple_fast`).

  It is **`pub(open)`**, not plain `pub`. MoonBit seals a `pub trait`: only the
  defining package may write `impl`s for it. That would have made the `@visit`
  view adapters (§4.1) impossible — they live in a different package from
  `NeighborSource`. Opening the trait is the whole reason those adapters can be
  written at all, and it is what lets downstream users plug their own graph
  types into every traversal and structural algorithm here.

- **`Measure`** (in `algo`): weight arithmetic for shortest-path / MST algorithms.
  ```moonbit
  pub trait Measure { zero() -> Self; add(Self, Self) -> Self; compare(Self, Self) -> Int }
  // impl Measure for Int, Double
  ```
  MoonBit traits cannot say "any number", so we enumerate `Int` and `Double` instances.

- **`BoundedMeasure : Measure`** (in `algo`): the extra operations needed by
  algorithms that must represent "unreachable" as a concrete saturating value,
  detect overflow while relaxing through it, or undo an addition.
  ```moonbit
  pub trait BoundedMeasure : Measure {
    max_value() -> Self
    checked_add(Self, Self) -> Self?   // None on overflow
    sub(Self, Self) -> Self
  }
  ```
  This merges what upstream petgraph splits across `BoundedMeasure`
  (`max`, `overflowing_add`) and the `Sub` half of `PositiveMeasure`, because
  the same four algorithms need both halves: `floyd_warshall` (sentinel +
  overflow-checked relaxation), `johnson` (potential reweighting
  `w + h(u) - h(v)`), `ford_fulkerson` / `dinics` (residual capacities), and
  `steiner_tree`. For `Int`, `max_value()` is `2147483647` and `checked_add`
  detects sign-flip overflow; for `Double` it is `+inf`, which saturates rather
  than overflowing.

### 4.1 View adapters

`@visit` provides four adapters, each of which *implements* `NeighborSource`
rather than being special-cased inside the traversals:

| Adapter | Effect |
|---|---|
| `Reversed(g)` | swaps `Outgoing` / `Incoming` |
| `NodeFiltered::from_fn(g, pred)` | hides nodes failing `pred`, in `node_ids` and in every neighbour list |
| `EdgeFiltered::from_fn(g, pred)` | hides edges failing `pred`; concrete over `Graph[N, E]`, because edge identity is not expressible through `NeighborSource` |
| `UndirectedAdaptor(g)` | presents a directed graph as undirected |

Because they are ordinary `NeighborSource` implementations, they compose with
each other and with every existing traversal and structural algorithm without a
line of change to either side. `NodeFiltered::node_count` deliberately reports
the *underlying* node count, not the kept count: the traversals use it only to
size a `VisitMap` indexed by underlying node index.

Note that Kosaraju's SCC still spells its reverse pass as
`neighbors_directed(n, dir.opposite())` inline, predating `Reversed`; both are
correct and the duplication is deliberate for now (see §7).

Everything else operates on the concrete `Graph[N, E]` plus an `edge_cost` closure where
weights matter — mirroring petgraph's `edge_cost: FnMut` parameter. This keeps weight
generics out of the graph type and matches "concrete + a light trait" design choice.

## 5. Algorithms & their building blocks

| Algorithm | Technique | Key dependency |
|-----------|-----------|----------------|
| `dijkstra` | binary heap + visited map | `@priority_queue`, `Measure` |
| `astar` | heap + heuristic | reuses dijkstra's `MinScored` |
| `bidirectional_dijkstra` | simultaneous forward/backward search | `Measure` |
| `bellman_ford` | edge relaxation, negative-cycle detection | `Measure` |
| `spfa` | queue-based Bellman–Ford | `Measure` |
| `find_negative_cycle` | Bellman–Ford predecessor walk | `Measure` |
| `k_shortest_path` | heap, k relaxations per node | `Measure` |
| `floyd_warshall` | O(V³) DP over all pairs | `BoundedMeasure` |
| `johnson` | Bellman–Ford potentials + per-source Dijkstra | `BoundedMeasure` |
| `toposort` | Kahn / DFS via `Topo` | `visit` |
| `is_cyclic_directed` | DFS back-edge | `visit` |
| `is_cyclic_undirected` | union of edges | `unionfind` |
| `greedy_feedback_arc_set` | bucketed sequence heuristic | — |
| `connected_components` | union of edges | `unionfind` |
| `kosaraju_scc` | two DFS passes (fwd + reversed) | `NeighborSource` |
| `tarjan_scc` | single DFS, lowlink | `NeighborSource` |
| `condensation` | contract each SCC to one node | `tarjan_scc` |
| `articulation_points` / `bridges` | DFS discovery/low values | `NeighborSource` |
| `simple_fast` (dominators) | Cooper–Harvey–Kennedy iterative fixpoint | `NeighborSource` |
| `has_path_connecting` / `is_bipartite_undirected` | DFS / 2-colouring BFS | `NeighborSource` |
| `min_spanning_tree` | Kruskal (sort edges + union) | `unionfind`, `Measure` |
| `min_spanning_tree_prim` | Prim (heap-driven frontier) | `@priority_queue`, `Measure` |
| `steiner_tree` | Kou's 2-approximation | `BoundedMeasure` |
| `ford_fulkerson` | Edmonds–Karp augmenting paths | `BoundedMeasure` |
| `dinics` | level graph + blocking flow | `BoundedMeasure` |
| `greedy_matching` / `maximum_matching` | greedy warm start / Gabow's blossom | — |
| `maximal_cliques` | Bron–Kerbosch with pivoting | — |
| `dsatur_coloring` | saturation-degree greedy | `@priority_queue` |
| `all_simple_paths` | lazy backtracking enumeration | — |
| `dag_transitive_reduction_closure` | toposorted bitset propagation | — |

**Priority queue.** `@priority_queue` from `moonbitlang/core` is a max-heap keyed by
`Compare`. We define `MinScored(K, NodeId)` with a reversed `Compare` so the heap pops the
smallest cost — exactly petgraph's `scored::MinScored` trick.

**Undirected edge traversal.** An undirected edge is stored once, as a fixed
`(src, dst)` pair, but appears in *both* endpoints' incident lists. Any
algorithm that walks a node's incident edges must therefore ask for "the
endpoint away from this node", never for the edge's stored `dst`. `Graph::edges(a)`
does that normalization (petgraph's `Edges` / `EdgeRef::target` semantics) and is
what the weighted algorithms use. Reading `edge_endpoints(e).1` instead is a
silent correctness bug on undirected graphs — one this port actually shipped
before it was caught; see `src/algo/undirected_regression_test.mbt`.

## 6. Testing strategy

See `docs/TESTING.md`. In brief: black-box `*_test.mbt` for every public API (using petgraph
as the behavioural oracle), white-box `*_wbtest.mbt` for the intrusive-edge-list invariants
and union-find internals, snapshot tests for DOT output, and property-style cross-checks
(e.g. dijkstra ≤ bellman_ford on non-negative graphs; component count vs SCC count).

## 7. Known limitations / future work

- No `StableGraph`/`GraphMap`/`Csr`/`MatrixGraph` yet. Beyond the missing
  representations themselves, this is why a few upstream tests could not be
  ported (they rely on `StableGraph`'s stable indices, which `Graph`'s
  swap-remove cannot reproduce) and why `steiner_tree` returns `Array[EdgeId]`
  where upstream returns a `StableGraph`.
- Neighbour / node / edge iteration returns a lazy `Iter[_]` (idiomatic MoonBit; each accessor
  call yields a fresh single-use iterator). Algorithms needing random access or repeated passes
  over one node's neighbours materialise locally with `.to_array()` (e.g. iterative `tarjan_scc`).
- `Measure` and `BoundedMeasure` are instantiated for `Int`/`Double` only.
- **Known internal duplication.** Three shortest-path routines are inlined
  rather than reusing `dijkstra`: `johnson` needs direction-aware reweighting
  (`w + h(u) - h(v)`), which an `(EdgeId) -> K` cost closure cannot express;
  `steiner_tree` carries its own all-pairs routine ported from upstream's
  `floyd_warshall_path`, because the predecessor-matrix variant of
  `floyd_warshall` is not exposed here; and `kosaraju_scc` predates the
  `Reversed` adapter. None is a correctness problem, but all three are worth
  consolidating.
- `dinics` diverges from upstream on one degenerate input: where petgraph loops
  forever for `source == destination`, this port returns zero flow.
