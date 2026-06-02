# petgraph for MoonBit

[![CI](https://github.com/I3eg1nner/moonbit-petgraph/actions/workflows/ci.yml/badge.svg)](https://github.com/I3eg1nner/moonbit-petgraph/actions/workflows/ci.yml)

**English** | [中文](README.zh.md)

A MoonBit port of the Rust [petgraph](https://github.com/petgraph/petgraph)
library — fast, flexible **graph data structures and algorithms**, supporting
both directed and undirected graphs with arbitrary node and edge data.

This port focuses on the most-used core of petgraph:

- **`@graph`** — an adjacency-list `Graph[N, E]` (directed & undirected) with
  typed `NodeId`/`EdgeId`, neighbour iteration, edge lookup, and stable
  swap-remove semantics.
- **`@unionfind`** — a disjoint-set structure (union-by-rank + path compression).
- **`@visit`** — traversals `Dfs`, `Bfs`, `DfsPostOrder`, `Topo`, and an
  event-driven `depth_first_search`.
- **`@algo`** — `dijkstra`, `astar`, `bellman_ford`, `toposort`, cycle
  detection, `connected_components`, strongly-connected components
  (`kosaraju_scc` / `tarjan_scc`), and `min_spanning_tree` (Kruskal).
- **`@dot`** — Graphviz **DOT** export for visualization.

## Project goals

Provide a clear, idiomatic, well-tested MoonBit graph library whose behaviour
matches petgraph's, with continuous integration, documentation, and reproducible
examples. See [`docs/DESIGN.md`](docs/DESIGN.md) for the architecture and the
Rust→MoonBit adaptation rationale.

## Installation

This is a standard MoonBit module. Add it as a dependency of your project:

```bash
moon add moonbit-community/petgraph
```

Then import the sub-packages you need in your package's `moon.pkg`:

```json
{
  "import": [
    "moonbit-community/petgraph/graph",
    "moonbit-community/petgraph/algo",
    "moonbit-community/petgraph/dot"
  ]
}
```

To build this repository from source:

```bash
git clone <repo-url> && cd petgraph_mbt
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
  // `@algo.Cycle` on a cyclic graph (use `try?` to get a `Result` instead).
  let order = @algo.toposort(g)
  debug_inspect(order.length(), content="4")
  // No directed cycle.
  debug_inspect(@algo.is_cyclic_directed(g), content="false")
}
```

## Documentation

- [`docs/DESIGN.md`](docs/DESIGN.md) — architecture & design decisions.
- [`docs/TESTING.md`](docs/TESTING.md) — how the library is tested.
- [`docs/TODO.md`](docs/TODO.md) — scope and migration progress.

中文文档(Chinese):

- [`docs/测试文档.md`](docs/测试文档.md) — 详细测试文档(用例清单、覆盖率、缺陷修复)。
- [`docs/开发报告.md`](docs/开发报告.md) — 开发报告(目标、设计决策、流程、问题与复现)。

## License

Dual-licensed under [MIT](LICENSE-MIT) or
[Apache-2.0](LICENSE-APACHE), matching upstream petgraph.
