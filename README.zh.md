# petgraph for MoonBit

[![CI](https://github.com/V1GreenSummer/moonbit-petgraph/actions/workflows/ci.yml/badge.svg)](https://github.com/V1GreenSummer/moonbit-petgraph/actions/workflows/ci.yml)

[English](README.md) | **中文**

Rust [petgraph](https://github.com/petgraph/petgraph) 库的 MoonBit 移植——快速、灵活的
**图数据结构与算法**,支持任意结点/边数据的有向图与无向图。

- **`@graph`** —— 邻接表 `Graph[N, E]`(有向 & 无向),带类型化的 `NodeId`/`EdgeId`、
  邻居与边引用遍历、边查找、`map` / `filter_map` / `retain_*` 变换,以及稳定的
  swap-remove 语义。
- **`@unionfind`** —— 并查集(按秩合并 + 路径压缩)。
- **`@visit`** —— 遍历器 `Dfs`、`Bfs`、`DfsPostOrder`、`Topo`,事件驱动的
  `depth_first_search`,以及可与上述全部遍历器组合使用的视图适配器 `Reversed`、
  `NodeFiltered`、`EdgeFiltered` 与 `UndirectedAdaptor`。
- **`@algo`** —— 35 个算法:最短路径(Dijkstra、A\*、Bellman–Ford、Floyd–Warshall、
  Johnson、SPFA、双向 Dijkstra、k 最短路径)、连通性(强连通分量、割点、桥、支配树、
  凝聚图、二分图判定)、生成树与 Steiner 树、最大流(Ford–Fulkerson、Dinic)、
  匹配(贪心与 Gabow 带花树算法)、着色、极大团、简单路径枚举、反馈弧集,以及 DAG
  传递归约。
- **`@dot`** —— 导出 Graphviz **DOT** 用于可视化。

未移植的部分:petgraph 的其他图表示(`StableGraph`、`GraphMap`、`MatrixGraph`、
`Csr`、`adj::List`)、其 serde 支持,以及 graph6 / DOT **解析器**。当前的范围边界见
[`docs/TODO.md`](docs/TODO.md)。

## 项目目标

提供一个清晰、地道、充分测试的 MoonBit 图库,其行为与 petgraph 一致,并配备持续集成、
文档与可复现的示例。架构与 Rust→MoonBit 的适配取舍见
[`docs/DESIGN.md`](docs/DESIGN.md)。

## 安装

这是一个标准的 MoonBit 模块。把它作为依赖加入你的项目:

```bash
moon add I3eg1nner/petgraph
```

> mooncakes.io 上的包命名空间是 `I3eg1nner/`，而本仓库托管在 `github.com/V1GreenSummer/`。
> 两个账号同属一位作者：命名空间跟随发布账号，仓库地址跟随源码所在位置。

然后在你所在包的 `moon.pkg` 里按需导入子包:

```json
{
  "import": [
    "I3eg1nner/petgraph/graph",
    "I3eg1nner/petgraph/algo",
    "I3eg1nner/petgraph/dot"
  ]
}
```

从源码构建本仓库:

```bash
git clone https://github.com/V1GreenSummer/moonbit-petgraph.git && cd moonbit-petgraph
moon check        # type-check
moon test         # run the test suite
moon run src/cmd/main   # run the demo
```

## 使用

构建一张图、运行算法、查看结果。下面这个示例会作为测试套件的一部分被编译并运行。

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

用 `@dot` + Graphviz 渲染后,上面这张无向图看起来是这样:

<img src="docs/demo-graph.svg" alt="demo 图(0–1–2–3 单位权环)经 Graphviz 渲染" width="110">

图中每个椭圆是一个**结点**(标签是结点权重,本例设为其下标 `0`–`3`),每条连线是一条
无向**边**(标签是边权,这里都是 `1`)。这正是上面构建的四元环 `0–1–2–3–0`:从结点 `0`
出发的 `dijkstra` 距离为 `{0: 0, 1: 1, 2: 2, 3: 1}`,而 `min_spanning_tree` 会保留 4 条边
中的 3 条——丢弃环上的一条边。

把图导出为 Graphviz DOT 以便可视化:

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

遍历与环检测:

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

计算最大流:

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

通过视图适配器遍历一张图——`Reversed` 沿反方向走边,而不必构造一份反向副本;由于它实现了
与 `Graph` 相同的 `NeighborSource` trait,因此适用于所有遍历器:

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

## 支持的接口

本库拆分为若干聚焦的子包,按需导入即可。下面采用 MoonBit 记法:`~` 表示带标签参数,
`?` 表示可选参数或 `Option` 结果,`raise` 表示可能抛出受检错误。

### `@graph` —— 图数据结构

- **构造**:`Graph::new()` / `Graph::new_undirected()`、
  `Graph::with_capacity(nodes, edges)`,以及 `from_edges(pairs)` /
  `from_edges_undirected(pairs)`——从 `(src, dst)` 下标对构建 `Graph[Int, Unit]`。
- **修改**:`add_node(w) -> NodeId`、`add_edge(a, b, w) -> EdgeId`、
  `update_edge(a, b, w)`(新增或覆盖)、`remove_node(n) -> N?`、
  `remove_edge(e) -> E?`(swap-remove,返回被删权重)、
  `set_node_weight` / `set_edge_weight`、`clear`、`clear_edges`、`reverse`。
- **查询**:`node_count`、`edge_count`、`is_directed`、`node_weight(n) -> N?`、
  `edge_weight(e) -> E?`、`edge_endpoints(e) -> (NodeId, NodeId)?`、
  `find_edge(a, b) -> EdgeId?`、`find_edge_undirected`、`contains_edge`。
- **遍历**(均返回全新的、惰性的单次消费 `Iter`):
  `node_ids() -> Iter[NodeId]`、`edge_ids() -> Iter[EdgeId]`、
  `node_weights() -> Iter[N]`、`edge_weights() -> Iter[E]`、
  `neighbors(n)` / `neighbors_directed(n, dir)` / `neighbors_undirected(n) -> Iter[NodeId]`、
  `edges_directed(n, dir) -> Iter[EdgeId]`、`externals(dir) -> Iter[NodeId]`
  (源点 / 汇点)。
- **边引用**:`edges(n) -> Iter[EdgeRef[E]]`(端点已归一化,`source` 恒为 `n`,无向边
  也是如此——正是这一点让带权算法在无向图上保持正确)、
  `edge_references() -> Iter[EdgeRef[E]]`(所有边,端点按存储形式给出)、
  `edges_connecting(a, b) -> Iter[EdgeId]`。
- **变换**:`map(node_map, edge_map)` / `filter_map(node_map, edge_map)`
  构建权重类型不同的新图,`retain_nodes(pred)` / `retain_edges(pred)`
  就地过滤,`extend_with_edges(pairs)`、`into_nodes_edges()`。
- **底层邻接遍历**:`first_edge(n, dir) -> EdgeId?`、
  `next_edge(e, dir) -> EdgeId?`。
- **类型**:`NodeId` / `EdgeId`(`::new`、`::index`)、`EdgeRef[E]`
  (`id` / `source` / `target` / `weight`)、`Direction`
  (`Outgoing` / `Incoming`、`.opposite()`)、`Directedness`,以及遍历与算法所泛化依赖的
  `NeighborSource` trait。

### `@unionfind` —— 并查集(按秩合并 + 路径压缩)

- `UnionFind::new(n)` / `new_empty()`、`new_set() -> Int`(追加一个元素)。
- `union(a, b) -> Bool`、`same_set(a, b) -> Bool`、`find(x) -> Int`、
  `into_labeling() -> Array[Int]`,以及带边界检查、返回 `Option` 的
  `try_union` / `try_same_set` / `try_find`。

### `@visit` —— 遍历

- 遍历器 `Dfs`、`Bfs`、`DfsPostOrder`、`Topo`:`::new(graph[, start])`,随后
  `.next(graph) -> NodeId?`;用 `reset` / `move_to` 重启。泛化于任意
  `NeighborSource`。每个遍历器还提供 `.iter(graph) -> Iter[NodeId]` 和
  `.walker(graph) -> Walker`,便于以迭代器方式驱动,而不必手写 `next` 循环。
- `depth_first_search(graph, starts, visitor)` —— 事件驱动的 DFS;`visitor` 收到一个
  `DfsEvent`(`Discover` / `TreeEdge` / `BackEdge` / `CrossForwardEdge` / `Finish`),
  返回一个 `Control`(`Continue` / `Prune` / `Break`)。
- **视图适配器**,每一个都实现了 `NeighborSource`,因此所有遍历器与所有以
  `NeighborSource` 泛化的算法都能原样作用其上,并且它们彼此之间还可以组合:
  - `Reversed(g)` —— 交换 `Outgoing` / `Incoming`。
  - `NodeFiltered::from_fn(g, pred)` —— 隐藏不满足 `pred` 的结点。
  - `EdgeFiltered::from_fn(g, pred)` —— 隐藏不满足 `pred` 的边;因为需要边的标识,
    所以只对具体的 `Graph[N, E]` 生效。
  - `UndirectedAdaptor(g)` —— 把有向图当作无向图呈现。
- `VisitMap` —— 以 `NodeId` 为键、可复用的已访问集合。

### `@algo` —— 算法

- **单源最短路径**:
  `dijkstra(g, start~, goal?, edge_cost~) -> Map[NodeId, K]`、
  `astar(g, start~, is_goal~, edge_cost~, estimate_cost~) -> (K, Array[NodeId])?`、
  `bellman_ford(g, source~, edge_cost~) -> BellmanFordPaths[K] raise NegativeCycle`、
  `spfa`(基于队列的 Bellman–Ford)、
  `bidirectional_dijkstra`、`k_shortest_path`、
  `find_negative_cycle(g, source~, edge_cost~) -> Array[NodeId]?`。
- **全源最短路径**:`floyd_warshall`、`johnson`(Bellman–Ford 势能 + 逐源点
  Dijkstra,因此允许负权边)。
- **排序与环**:`toposort(g) -> Array[NodeId] raise Cycle`、
  `is_cyclic_directed(g)`、`is_cyclic_undirected(g)`、
  `greedy_feedback_arc_set(g) -> Array[EdgeId]`。
- **连通性**:`connected_components(g) -> Int`、
  `kosaraju_scc(g)` / `tarjan_scc(g) -> Array[Array[NodeId]]`、
  `condensation(g, make_acyclic)`、`articulation_points(g)`、`bridges(g)`、
  `has_path_connecting(g, a, b, space?)`、`is_bipartite_undirected(g, start)`、
  `simple_fast(g, root) -> Dominators`(Cooper–Harvey–Kennedy 支配树)。
- **生成树**:`min_spanning_tree(g, edge_cost~) -> Array[EdgeId]`(Kruskal)、
  `min_spanning_tree_prim(g, edge_cost~)`(Prim)、
  `steiner_tree(g, terminals, edge_cost~)`(Kou 近似算法)。
- **最大流**:`ford_fulkerson(g, source~, destination~, edge_cost~)` 与
  `dinics(...)`,均返回 `(max_flow, per_edge_flows)`。
- **匹配**:`greedy_matching(g)` 与 `maximum_matching(g)`(Gabow 带花树算法,
  在一般非二分图上同样正确),返回一个 `Matching`,提供
  `mate` / `contains_edge` / `is_perfect` / `edges` / `nodes`。
- **枚举与着色**:`maximal_cliques(g)`(带枢轴的 Bron–Kerbosch)、
  `all_simple_paths` / `all_simple_paths_multi`(惰性)、
  `dsatur_coloring(g) -> (Map[NodeId, Int], Int)`。
- **DAG 工具**:`dag_to_toposorted_adjacency_list`、
  `dag_transitive_reduction_closure`。
- 边代价泛化于 `Measure` trait(`zero` / `add` / `compare`)。
  需要饱和的「不可达」值、带溢出检查的松弛或减法的算法——Floyd–Warshall、Johnson、
  两个最大流算法、Steiner——使用 `BoundedMeasure : Measure`
  (`max_value` / `checked_add` / `sub`)。两个 trait 都已为 `Int`
  与 `Double` 实现。

### `@dot` —— Graphviz 导出

- `to_dot(g, config?) -> String`(要求 `N : Show`、`E : Show`);`config` 是
  `DotConfig` 标志数组:`NodeIndexLabel`、`EdgeIndexLabel`、`EdgeNoLabel`、
  `NodeNoLabel`、`GraphContentOnly`。
- `to_dot` 只生成 DOT **字符串**;要渲染成图片需要安装
  [Graphviz](https://graphviz.org)(例如 `apt-get install graphviz`),再把字符串
  通过 `dot` 渲染:

  ```bash
  # Print just the DOT block from the demo and render it.
  moon run src/cmd/main | sed -n '/^\(di\)\?graph {/,/^}/p' | dot -Tsvg -o graph.svg
  ```

  或把字符串贴到在线查看器,例如
  [GraphvizOnline](https://dreampuf.github.io/GraphvizOnline/)。

## 从 Rust petgraph 迁移

`本移植` 的 API 高度贴合 petgraph——大多数名字完全一致,petgraph 代码几乎原样可读。
只有少数几处为顺应 MoonBit 惯用法做了有意的调整。

**完全一致的命名**

- `@graph`:`Graph::new` / `new_undirected` / `with_capacity` / `from_edges`;
  `add_node` / `add_edge` / `update_edge` / `remove_node` / `remove_edge`;
  `node_weight` / `edge_weight` / `edge_endpoints` / `find_edge` /
  `find_edge_undirected` / `contains_edge` / `node_count` / `edge_count` /
  `is_directed` / `externals` / `reverse`;`neighbors` / `neighbors_directed` /
  `neighbors_undirected`。
- `@algo`:`dijkstra`、`astar`、`bellman_ford`、`spfa`、`floyd_warshall`、
  `johnson`、`k_shortest_path`、`bidirectional_dijkstra`、`find_negative_cycle`、
  `toposort`、`is_cyclic_directed`、`is_cyclic_undirected`、
  `greedy_feedback_arc_set`、`connected_components`、`kosaraju_scc`、
  `tarjan_scc`、`condensation`、`articulation_points`、`bridges`、`simple_fast`、
  `has_path_connecting`、`is_bipartite_undirected`、`min_spanning_tree`、
  `min_spanning_tree_prim`、`steiner_tree`、`ford_fulkerson`、`dinics`、
  `greedy_matching`、`maximum_matching`、`maximal_cliques`、`dsatur_coloring`、
  `all_simple_paths`、`all_simple_paths_multi`、
  `dag_transitive_reduction_closure`。
- `@visit`:`Dfs`、`Bfs`、`DfsPostOrder`、`Topo`、`depth_first_search`、
  `DfsEvent`、`Control`、`Reversed`、`NodeFiltered`、`EdgeFiltered`、
  `Direction::{Outgoing, Incoming}`。
- `@unionfind`:`UnionFind` —— `union` / `find` / `find_mut` / `new_set` /
  `into_labeling`。

**有意的差异**

| Rust petgraph | 本移植 | 原因 |
|---|---|---|
| `NodeIndex` / `EdgeIndex` | `NodeId` / `EdgeId`(保留 `.index()`) | 更短;并非 Rust 的 index newtype |
| `node_indices()` / `edge_indices()` | `node_ids()` / `edge_ids()` | 随 `NodeId` 改名 |
| 具名迭代器(`Neighbors`、`NodeIndices` 等) | 惰性 `Iter[T]` | MoonBit 标准迭代器;`for x in …` 用法完全一致 |
| `toposort -> Result<_, Cycle>` | `toposort(…) raise Cycle` | MoonBit 错误惯用法——用 `try … catch` 捕获 |
| `bellman_ford -> Result<_, NegativeCycle>` | `… raise NegativeCycle` | 同上 |
| `Ty` 类型参数(`Directed` / `Undirected`) | 运行时 `new` 与 `new_undirected` 二选一 | 不用常量泛型表达有向性 |
| `Measure` / `FloatMeasure` / `PositiveMeasure` / `BoundedMeasure` | `Measure` 与 `BoundedMeasure`(`Int`、`Double`) | 没有可依托的数值塔 trait;上游四个约束合并为两个 |
| `GraphBase` / `IntoNeighbors` / `Visitable` / …(18 个 trait) | 单个 `pub(open) trait NeighborSource` | MoonBit 没有关联类型与 GAT;一个 trait 就覆盖了遍历器真正需要的能力 |
| `EdgeReference`(借用) | `EdgeRef[E]`(拥有所有权的结构体,`derive(Debug)`) | 没有生命周期 |
| `min_spanning_tree -> Iterator<Element>` | `-> Array[EdgeId]` | 这里 id 很廉价;调用方自行从图中读取权重 |
| `steiner_tree -> StableGraph` | `-> Array[EdgeId]` | 本移植没有 `StableGraph` |
| `dinics` 在 `source == destination` 时挂死 | 返回零流量 | 不终止的调用比行为偏差更糟 |

## 文档

- [`docs/DESIGN.md`](docs/DESIGN.md) —— 架构与设计决策(英文)。
- [`docs/TESTING.md`](docs/TESTING.md) —— 测试方式说明(英文)。
- [`docs/TODO.md`](docs/TODO.md) —— 范围与迁移进度(英文)。
- [`docs/THIRD_PARTY.md`](docs/THIRD_PARTY.md) —— 上游 petgraph 的署名、许可证,
  以及被参考内容的范围(英文)。

中文文档:

- [`docs/测试文档.md`](docs/测试文档.md) —— 详细测试文档(用例清单、覆盖率、缺陷修复)。
- [`docs/开发报告.md`](docs/开发报告.md) —— 开发报告(目标、设计决策、流程、问题与复现)。

## 许可证

采用 [MIT](LICENSE-MIT) 或 [Apache-2.0](LICENSE-APACHE) 双重许可,与上游 petgraph 保持一致。
