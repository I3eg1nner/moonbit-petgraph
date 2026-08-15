# petgraph for MoonBit

[![CI](https://github.com/V1GreenSummer/moonbit-petgraph/actions/workflows/ci.yml/badge.svg)](https://github.com/V1GreenSummer/moonbit-petgraph/actions/workflows/ci.yml)

**English** | [中文](README.zh.md)

A MoonBit port of the Rust [petgraph](https://github.com/petgraph/petgraph)
library — fast, flexible **graph data structures and algorithms**, supporting
both directed and undirected graphs with arbitrary node and edge data.

- **`@graph`** — an adjacency-list `Graph[N, E]` (directed & undirected) with
  typed `NodeId`/`EdgeId`, neighbour and edge-reference iteration, edge lookup,
  `map` / `filter_map` / `retain_*` transforms, and stable swap-remove semantics.
- **`@unionfind`** — a disjoint-set structure (union-by-rank + path compression).
- **`@visit`** — traversals `Dfs`, `Bfs`, `DfsPostOrder`, `Topo`, an
  event-driven `depth_first_search`, and the view adapters `Reversed`,
  `NodeFiltered`, `EdgeFiltered` and `UndirectedAdaptor` that compose with all
  of them.
- **`@algo`** — 35 algorithms: shortest paths (Dijkstra, A\*, Bellman–Ford,
  Floyd–Warshall, Johnson, SPFA, bidirectional Dijkstra, k-shortest-path),
  connectivity (SCC, articulation points, bridges, dominators, condensation,
  bipartiteness), spanning and Steiner trees, maximum flow (Ford–Fulkerson,
  Dinic's), matching (greedy and Gabow's blossom algorithm), colouring, maximal
  cliques, simple-path enumeration, feedback arc sets and DAG transitive
  reduction.
- **`@dot`** — Graphviz **DOT** export for visualization.

Not ported: petgraph's alternative graph representations (`StableGraph`,
`GraphMap`, `MatrixGraph`, `Csr`, `adj::List`), its serde support, and its
graph6 / DOT *parsers*. See [`docs/TODO.md`](docs/TODO.md) for the current
boundary.

## Project goals

Provide a clear, idiomatic, well-tested MoonBit graph library whose behaviour
matches petgraph's, with continuous integration, documentation, and reproducible
examples. See [`docs/DESIGN.md`](docs/DESIGN.md) for the architecture and the
Rust→MoonBit adaptation rationale.

## Installation

This is a standard MoonBit module. Add it as a dependency of your project:

```bash
moon add V1GreenSummer/petgraph
```

Then import the sub-packages you need in your package's `moon.pkg`:

```json
{
  "import": [
    "V1GreenSummer/petgraph/graph",
    "V1GreenSummer/petgraph/algo",
    "V1GreenSummer/petgraph/dot"
  ]
}
```

To build this repository from source:

```bash
git clone https://github.com/V1GreenSummer/moonbit-petgraph.git && cd moonbit-petgraph
moon check        # type-check
moon test         # run the test suite
moon run src/cmd/main   # run the demo
```

## Usage

Build a graph, run an algorithm, and inspect the result. This example is
compiled and tested as part of the suite.

```mbt check
///|
test "shortest path and spanning tree" {
  // An undirected graph with `Int` node and edge weights.
  //
  //   0 -- 1
  //   |    |
  //   3 -- 2
  let g : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
  let n0 = g.add_node(0)
  let n1 = g.add_node(1)
  let n2 = g.add_node(2)
  let n3 = g.add_node(3)
  let _ = g.add_edge(n0, n1, 1)
  let _ = g.add_edge(n1, n2, 1)
  let _ = g.add_edge(n2, n3, 1)
  let _ = g.add_edge(n0, n3, 1)

  // Shortest-path distances from node 0 (each edge costs its weight).
  let dist = @algo.dijkstra(g, start=n0, edge_cost=fn(e) {
    g.edge_weight(e).unwrap()
  })
  // Distance to node 2 is 2 (via 0-1-2 or 0-3-2).
  debug_inspect(dist.get(n2), content="Some(2)")

  // Minimum spanning tree (Kruskal): the 4-cycle drops exactly one edge.
  let mst = @algo.min_spanning_tree(g, edge_cost=fn(e) {
    g.edge_weight(e).unwrap()
  })
  debug_inspect(mst.length(), content="3")
}
```

Rendered with `@dot` and Graphviz, that undirected graph looks like this:

<img src="docs/demo-graph.svg" alt="The demo graph (0–1–2–3 cycle, unit weights) rendered with Graphviz" width="110">

Each ellipse is a **node** (its label is the node weight, which this example sets
equal to the index `0`–`3`) and each line is an undirected **edge** (its label is
the edge weight, all `1` here). This is the 4-cycle `0–1–2–3–0` built above:
`dijkstra` from node `0` gives distances `{0: 0, 1: 1, 2: 2, 3: 1}`, and
`min_spanning_tree` keeps 3 of the 4 edges — dropping one edge of the cycle.

Export a graph to Graphviz DOT for visualization:

```mbt check
///|
test "dot export" {
  let g : @graph.Graph[Int, Unit] = @graph.from_edges([(0, 1), (1, 2)])
  let dot = @dot.to_dot(g, config=[@dot.DotConfig::EdgeNoLabel])
  assert_eq(
    dot,
    (
      #|digraph {
      #|    0 [ label = "0" ]
      #|    1 [ label = "1" ]
      #|    2 [ label = "2" ]
      #|    0 -> 1 [ ]
      #|    1 -> 2 [ ]
      #|}
      #|
    ),
  )
}
```

Traverse and detect cycles:

```mbt check
///|
test "traversal and cycles" {
  // A directed acyclic graph: 0 -> 1 -> 3, 0 -> 2 -> 3.
  let g : @graph.Graph[Int, Unit] = @graph.from_edges([
    (0, 1),
    (0, 2),
    (1, 3),
    (2, 3),
  ])
  // Topological sort returns the order directly on a DAG, and raises
  // `@algo.Cycle` on a cyclic graph (wrap in `try … catch` to handle that).
  let order = @algo.toposort(g)
  debug_inspect(order.length(), content="4")
  // No directed cycle.
  debug_inspect(@algo.is_cyclic_directed(g), content="false")
}
```

Compute a maximum flow:

```mbt check
///|
test "maximum flow" {
  // A classic two-path network from source 0 to sink 3.
  //
  //        1
  //     3/   \2
  //   0        3
  //     2\   /3
  //        2
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  for i in 0..<4 {
    let _ = g.add_node(i)

  }
  let n = i => @graph.NodeId::new(i)
  let _ = g.add_edge(n(0), n(1), 3)
  let _ = g.add_edge(n(0), n(2), 2)
  let _ = g.add_edge(n(1), n(3), 2)
  let _ = g.add_edge(n(2), n(3), 3)
  let cost = e => g.edge_weight(e).unwrap()

  // Both algorithms agree on the value; the bottleneck is 2 + 2 = 4.
  let (dinics_flow, _) = @algo.dinics(g, source=n(0), destination=n(3), edge_cost=cost)
  let (ff_flow, _) = @algo.ford_fulkerson(
    g, source=n(0), destination=n(3), edge_cost=cost,
  )
  debug_inspect(dinics_flow, content="4")
  debug_inspect(ff_flow, content="4")
}
```

Traverse a graph through a view adapter — `Reversed` follows edges backwards
without building a reversed copy, and works with every traversal because it
implements the same `NeighborSource` trait a `Graph` does:

```mbt check
///|
test "reversed view" {
  // A directed path 0 -> 1 -> 2.
  let g : @graph.Graph[Int, Unit] = @graph.from_edges([(0, 1), (1, 2)])
  let start = @graph.NodeId::new(2)

  // Forwards from node 2 there is nowhere to go.
  let forward = @visit.Dfs::new(g, start).iter(g).collect()
  debug_inspect(forward.map(x => x.index()), content="[2]")

  // Reversed, node 2 reaches the whole path.
  let rev = @visit.Reversed(g)
  let backward = @visit.Dfs::new(rev, start).iter(rev).collect()
  debug_inspect(backward.map(x => x.index()), content="[2, 1, 0]")
}
```

## Supported API

The library is split into focused sub-packages; import only what you need.
Notation below is MoonBit: `~` marks a labelled argument, `?` an optional argument
or an `Option` result, and `raise` a checked error.

### `@graph` — graph data structure

- **Construct**: `Graph::new()` / `Graph::new_undirected()`,
  `Graph::with_capacity(nodes, edges)`, and `from_edges(pairs)` /
  `from_edges_undirected(pairs)` to build a `Graph[Int, Unit]` from `(src, dst)`
  index pairs.
- **Mutate**: `add_node(w) -> NodeId`, `add_edge(a, b, w) -> EdgeId`,
  `update_edge(a, b, w)` (add or overwrite), `remove_node(n) -> N?`,
  `remove_edge(e) -> E?` (swap-remove, returns the removed weight),
  `set_node_weight` / `set_edge_weight`, `clear`, `clear_edges`, `reverse`.
- **Query**: `node_count`, `edge_count`, `is_directed`, `node_weight(n) -> N?`,
  `edge_weight(e) -> E?`, `edge_endpoints(e) -> (NodeId, NodeId)?`,
  `find_edge(a, b) -> EdgeId?`, `find_edge_undirected`, `contains_edge`.
- **Iterate** (each returns a fresh, lazy single-use `Iter`):
  `node_ids() -> Iter[NodeId]`, `edge_ids() -> Iter[EdgeId]`,
  `node_weights() -> Iter[N]`, `edge_weights() -> Iter[E]`,
  `neighbors(n)` / `neighbors_directed(n, dir)` / `neighbors_undirected(n) -> Iter[NodeId]`,
  `edges_directed(n, dir) -> Iter[EdgeId]`, `externals(dir) -> Iter[NodeId]`
  (sources / sinks).
- **Edge references**: `edges(n) -> Iter[EdgeRef[E]]` (endpoints normalized so
  `source` is always `n`, even for undirected edges — this is what makes the
  weighted algorithms correct on undirected graphs),
  `edge_references() -> Iter[EdgeRef[E]]` (all edges, endpoints as stored),
  `edges_connecting(a, b) -> Iter[EdgeId]`.
- **Transform**: `map(node_map, edge_map)` / `filter_map(node_map, edge_map)`
  to build a new graph with different weight types, `retain_nodes(pred)` /
  `retain_edges(pred)` to filter in place, `extend_with_edges(pairs)`,
  `into_nodes_edges()`.
- **Low-level adjacency walk**: `first_edge(n, dir) -> EdgeId?`,
  `next_edge(e, dir) -> EdgeId?`.
- **Types**: `NodeId` / `EdgeId` (`::new`, `::index`), `EdgeRef[E]`
  (`id` / `source` / `target` / `weight`), `Direction`
  (`Outgoing` / `Incoming`, `.opposite()`), `Directedness`, and the
  `NeighborSource` trait that the traversals and algorithms are generic over.

### `@unionfind` — disjoint sets (union by rank + path compression)

- `UnionFind::new(n)` / `new_empty()`, `new_set() -> Int` to append an element.
- `union(a, b) -> Bool`, `same_set(a, b) -> Bool`, `find(x) -> Int`,
  `into_labeling() -> Array[Int]`, plus bounds-checked `try_union` /
  `try_same_set` / `try_find` variants returning `Option`.

### `@visit` — traversals

- Walkers `Dfs`, `Bfs`, `DfsPostOrder`, `Topo`: `::new(graph[, start])`, then
  `.next(graph) -> NodeId?`; `reset` / `move_to` to restart. Generic over any
  `NeighborSource`. Each also has `.iter(graph) -> Iter[NodeId]` and
  `.walker(graph) -> Walker` if you would rather drive it as an iterator than
  with a manual `next` loop.
- `depth_first_search(graph, starts, visitor)` — event-driven DFS; `visitor`
  receives a `DfsEvent` (`Discover` / `TreeEdge` / `BackEdge` /
  `CrossForwardEdge` / `Finish`) and returns a `Control`
  (`Continue` / `Prune` / `Break`).
- **View adapters**, each implementing `NeighborSource` so every traversal and
  every `NeighborSource`-generic algorithm works over them unchanged, and they
  compose with each other:
  - `Reversed(g)` — swaps `Outgoing` / `Incoming`.
  - `NodeFiltered::from_fn(g, pred)` — hides nodes failing `pred`.
  - `EdgeFiltered::from_fn(g, pred)` — hides edges failing `pred`; concrete over
    `Graph[N, E]`, since edge identity is needed.
  - `UndirectedAdaptor(g)` — presents a directed graph as undirected.
- `VisitMap` — a reusable visited-set keyed by `NodeId`.

### `@algo` — algorithms

- **Single-source shortest paths**:
  `dijkstra(g, start~, goal?, edge_cost~) -> Map[NodeId, K]`,
  `astar(g, start~, is_goal~, edge_cost~, estimate_cost~) -> (K, Array[NodeId])?`,
  `bellman_ford(g, source~, edge_cost~) -> BellmanFordPaths[K] raise NegativeCycle`,
  `spfa` (queue-based Bellman–Ford),
  `bidirectional_dijkstra`, `k_shortest_path`,
  `find_negative_cycle(g, source~, edge_cost~) -> Array[NodeId]?`.
- **All-pairs shortest paths**: `floyd_warshall`, `johnson` (Bellman–Ford
  potentials + per-source Dijkstra, so negative edges are allowed).
- **Order & cycles**: `toposort(g) -> Array[NodeId] raise Cycle`,
  `is_cyclic_directed(g)`, `is_cyclic_undirected(g)`,
  `greedy_feedback_arc_set(g) -> Array[EdgeId]`.
- **Connectivity**: `connected_components(g) -> Int`,
  `kosaraju_scc(g)` / `tarjan_scc(g) -> Array[Array[NodeId]]`,
  `condensation(g, make_acyclic)`, `articulation_points(g)`, `bridges(g)`,
  `has_path_connecting(g, a, b, space?)`, `is_bipartite_undirected(g, start)`,
  `simple_fast(g, root) -> Dominators` (Cooper–Harvey–Kennedy dominator tree).
- **Trees**: `min_spanning_tree(g, edge_cost~) -> Array[EdgeId]` (Kruskal),
  `min_spanning_tree_prim(g, edge_cost~)` (Prim),
  `steiner_tree(g, terminals, edge_cost~)` (Kou's approximation).
- **Maximum flow**: `ford_fulkerson(g, source~, destination~, edge_cost~)` and
  `dinics(...)`, each returning `(max_flow, per_edge_flows)`.
- **Matching**: `greedy_matching(g)` and `maximum_matching(g)` (Gabow's blossom
  algorithm, correct on general non-bipartite graphs), returning a `Matching`
  with `mate` / `contains_edge` / `is_perfect` / `edges` / `nodes`.
- **Enumeration & colouring**: `maximal_cliques(g)` (Bron–Kerbosch with
  pivoting), `all_simple_paths` / `all_simple_paths_multi` (lazy),
  `dsatur_coloring(g) -> (Map[NodeId, Int], Int)`.
- **DAG utilities**: `dag_to_toposorted_adjacency_list`,
  `dag_transitive_reduction_closure`.
- Edge costs are generic over the `Measure` trait (`zero` / `add` / `compare`).
  Algorithms that need a saturating "unreachable" value, overflow-checked
  relaxation or subtraction — Floyd–Warshall, Johnson, both max-flow
  algorithms, Steiner — use `BoundedMeasure : Measure`
  (`max_value` / `checked_add` / `sub`). Both traits are implemented for `Int`
  and `Double`.

### `@dot` — Graphviz export

- `to_dot(g, config?) -> String` (requires `N : Show`, `E : Show`); `config` is an
  array of `DotConfig` flags: `NodeIndexLabel`, `EdgeIndexLabel`, `EdgeNoLabel`,
  `NodeNoLabel`, `GraphContentOnly`.
- `to_dot` only produces the DOT *string*; to render it to an image you need
  [Graphviz](https://graphviz.org) (e.g. `apt-get install graphviz`), then pipe
  the string through `dot`:

  ```bash
  # Print just the DOT block from the demo and render it.
  moon run src/cmd/main | sed -n '/^\(di\)\?graph {/,/^}/p' | dot -Tsvg -o graph.svg
  ```

  Or paste the string into an online viewer such as
  [GraphvizOnline](https://dreampuf.github.io/GraphvizOnline/).

## Coming from Rust petgraph

`This port` mirrors petgraph's API closely — most names are identical, so
petgraph code reads almost unchanged. A few things were deliberately adapted to
MoonBit idioms.

**Identical names**

- `@graph`: `Graph::new` / `new_undirected` / `with_capacity` / `from_edges`;
  `add_node` / `add_edge` / `update_edge` / `remove_node` / `remove_edge`;
  `node_weight` / `edge_weight` / `edge_endpoints` / `find_edge` /
  `find_edge_undirected` / `contains_edge` / `node_count` / `edge_count` /
  `is_directed` / `externals` / `reverse`; `neighbors` / `neighbors_directed` /
  `neighbors_undirected`.
- `@algo`: `dijkstra`, `astar`, `bellman_ford`, `spfa`, `floyd_warshall`,
  `johnson`, `k_shortest_path`, `bidirectional_dijkstra`, `find_negative_cycle`,
  `toposort`, `is_cyclic_directed`, `is_cyclic_undirected`,
  `greedy_feedback_arc_set`, `connected_components`, `kosaraju_scc`,
  `tarjan_scc`, `condensation`, `articulation_points`, `bridges`, `simple_fast`,
  `has_path_connecting`, `is_bipartite_undirected`, `min_spanning_tree`,
  `min_spanning_tree_prim`, `steiner_tree`, `ford_fulkerson`, `dinics`,
  `greedy_matching`, `maximum_matching`, `maximal_cliques`, `dsatur_coloring`,
  `all_simple_paths`, `all_simple_paths_multi`,
  `dag_transitive_reduction_closure`.
- `@visit`: `Dfs`, `Bfs`, `DfsPostOrder`, `Topo`, `depth_first_search`,
  `DfsEvent`, `Control`, `Reversed`, `NodeFiltered`, `EdgeFiltered`,
  `Direction::{Outgoing, Incoming}`.
- `@unionfind`: `UnionFind` — `union` / `find` / `find_mut` / `new_set` /
  `into_labeling`.

**Deliberate differences**

| Rust petgraph | This port | why |
|---|---|---|
| `NodeIndex` / `EdgeIndex` | `NodeId` / `EdgeId` (`.index()` kept) | shorter; not a Rust index newtype |
| `node_indices()` / `edge_indices()` | `node_ids()` / `edge_ids()` | follows the `NodeId` rename |
| named iterators (`Neighbors`, `NodeIndices`, …) | lazy `Iter[T]` | MoonBit's standard iterator; `for x in …` is identical |
| `toposort -> Result<_, Cycle>` | `toposort(…) raise Cycle` | MoonBit error idiom — handle with `try … catch` |
| `bellman_ford -> Result<_, NegativeCycle>` | `… raise NegativeCycle` | same |
| `Ty` type parameter (`Directed` / `Undirected`) | runtime `new` vs `new_undirected` | no const-generic directedness |
| `Measure` / `FloatMeasure` / `PositiveMeasure` / `BoundedMeasure` | `Measure` and `BoundedMeasure` (`Int`, `Double`) | no numeric-tower traits to build on; four upstream bounds collapse into two |
| `GraphBase` / `IntoNeighbors` / `Visitable` / … (18 traits) | one `pub(open) trait NeighborSource` | MoonBit has no associated types or GATs; one trait covers what the traversals actually need |
| `EdgeReference` (borrowed) | `EdgeRef[E]` (owning struct, `derive(Debug)`) | no lifetimes |
| `min_spanning_tree -> Iterator<Element>` | `-> Array[EdgeId]` | ids are cheap here; caller reads weights from the graph |
| `steiner_tree -> StableGraph` | `-> Array[EdgeId]` | no `StableGraph` in this port |
| `dinics` hangs when `source == destination` | returns zero flow | a non-terminating call is worse than a divergence |

## Documentation

- [`docs/DESIGN.md`](docs/DESIGN.md) — architecture & design decisions.
- [`docs/TESTING.md`](docs/TESTING.md) — how the library is tested.
- [`docs/TODO.md`](docs/TODO.md) — scope and migration progress.
- [`docs/THIRD_PARTY.md`](docs/THIRD_PARTY.md) — upstream petgraph attribution,
  licenses, and the scope of what was referenced.

中文文档(Chinese):

- [`docs/测试文档.md`](docs/测试文档.md) — 详细测试文档(用例清单、覆盖率、缺陷修复)。
- [`docs/开发报告.md`](docs/开发报告.md) — 开发报告(目标、设计决策、流程、问题与复现)。

## License

Dual-licensed under [MIT](LICENSE-MIT) or
[Apache-2.0](LICENSE-APACHE), matching upstream petgraph.
