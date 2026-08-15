///|
/// `V1GreenSummer/petgraph` is a MoonBit port of the Rust
/// [petgraph](https://github.com/petgraph/petgraph) library: graph data
/// structures and algorithms.
///
/// The functionality is organised into sub-packages, which you import directly:
///
/// - `@graph` — the core adjacency-list `Graph[N, E]` (directed & undirected),
///   node/edge ids, and neighbour access.
/// - `@unionfind` — a disjoint-set (`UnionFind`) data structure.
/// - `@visit` — graph traversals (`Dfs`, `Bfs`, `DfsPostOrder`, `Topo`), the
///   `depth_first_search` event walker, and the `Reversed` / `NodeFiltered` /
///   `EdgeFiltered` / `UndirectedAdaptor` view adapters.
/// - `@algo` — 35 algorithms: shortest paths (Dijkstra, A*, Bellman-Ford,
///   Floyd-Warshall, Johnson, SPFA, k-shortest-path), connectivity (SCC,
///   articulation points, bridges, dominators, condensation, bipartiteness),
///   spanning and Steiner trees, maximum flow (Ford-Fulkerson, Dinic's),
///   matching (greedy and Gabow's blossom algorithm), colouring, maximal
///   cliques, simple-path enumeration, feedback arc sets, and DAG transitive
///   reduction.
/// - `@dot` — Graphviz DOT export.
///
/// See `README.md` for worked examples.

///|
/// The semantic version of this library.
///
/// Kept in sync with the `version` field of `moon.mod`.
pub fn version() -> String {
  "0.2.0"
}
