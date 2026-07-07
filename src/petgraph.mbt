///|
/// `wuyaxin/petgraph` is a MoonBit port of the Rust
/// [petgraph](https://github.com/petgraph/petgraph) library: graph data
/// structures and algorithms.
///
/// The functionality is organised into sub-packages, which you import directly:
///
/// - `@graph` — the core adjacency-list `Graph[N, E]` (directed & undirected),
///   node/edge ids, and neighbour access.
/// - `@unionfind` — a disjoint-set (`UnionFind`) data structure.
/// - `@visit` — graph traversals (`Dfs`, `Bfs`, `DfsPostOrder`, `Topo`) and
///   the `depth_first_search` event walker.
/// - `@algo` — algorithms: `dijkstra`, `astar`, `bellman_ford`, `toposort`,
///   cycle detection, connected components, SCC (Kosaraju/Tarjan) and MST.
/// - `@dot` — Graphviz DOT export.
///
/// See `README.md` for a worked example.

///|
/// The semantic version of this library.
pub fn version() -> String {
  "0.1.0"
}
