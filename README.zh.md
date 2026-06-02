# petgraph for MoonBit

[English](README.md) | **中文**

Rust [petgraph](https://github.com/petgraph/petgraph) 库的 MoonBit 移植——快速、灵活的
**图数据结构与算法**,支持任意结点/边数据的有向图与无向图。

本移植聚焦 petgraph 最常用的核心:

- **`@graph`** —— 邻接表 `Graph[N, E]`(有向 & 无向),带类型化的 `NodeId`/`EdgeId`、
  邻居遍历、边查找,以及稳定的 swap-remove 语义。
- **`@unionfind`** —— 并查集(按秩合并 + 路径压缩)。
- **`@visit`** —— 遍历器 `Dfs`、`Bfs`、`DfsPostOrder`、`Topo`,以及事件驱动的
  `depth_first_search`。
- **`@algo`** —— `dijkstra`、`astar`、`bellman_ford`、`toposort`、环检测、
  `connected_components`、强连通分量(`kosaraju_scc` / `tarjan_scc`),以及
  `min_spanning_tree`(Kruskal)。
- **`@dot`** —— 导出 Graphviz **DOT** 用于可视化。

## 项目目标

提供一个清晰、地道、充分测试的 MoonBit 图库,其行为与 petgraph 一致,并配备持续集成、
文档与可复现的示例。架构与 Rust→MoonBit 的适配取舍见
[`docs/DESIGN.md`](docs/DESIGN.md)。

## 安装

这是一个标准的 MoonBit 模块。把它作为依赖加入你的项目:

```bash
moon add moonbit-community/petgraph
```

然后在你所在包的 `moon.pkg` 里按需导入子包:

```json
{
  "import": [
    "moonbit-community/petgraph/graph",
    "moonbit-community/petgraph/algo",
    "moonbit-community/petgraph/dot"
  ]
}
```

从源码构建本仓库:

```bash
git clone <repo-url> && cd petgraph_mbt
moon check        # 类型检查
moon test         # 运行测试套件
moon run src/cmd/main   # 运行演示
```

## 使用

构建一张图、运行算法、查看结果。下面这个示例会作为测试套件的一部分被编译并运行
(测试源在 `src/README.mbt.md`)。

```mbt check
///|
test "shortest path and spanning tree" {
  // 一张带 `Int` 结点权与边权的无向图。
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

  // 从结点 0 出发的最短距离(每条边的代价取其权重)。
  let dist = @algo.dijkstra(g, start=n0, edge_cost=fn(e) {
    g.edge_weight(e).unwrap()
  })
  // 到结点 2 的距离为 2(经 0-1-2 或 0-3-2)。
  debug_inspect(dist.get(n2), content="Some(2)")

  // 最小生成树(Kruskal):四元环恰好丢弃一条边。
  let mst = @algo.min_spanning_tree(g, edge_cost=fn(e) {
    g.edge_weight(e).unwrap()
  })
  debug_inspect(mst.length(), content="3")
}
```

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
  // 一张有向无环图(DAG):0 -> 1 -> 3, 0 -> 2 -> 3。
  let g : @graph.Graph[Int, Unit] = @graph.from_edges([
    (0, 1),
    (0, 2),
    (1, 3),
    (2, 3),
  ])
  // 在 DAG 上拓扑排序成功。
  match @algo.toposort(g) {
    Ok(order) => debug_inspect(order.length(), content="4")
    Err(_) => fail("expected a DAG")
  }
  // 不存在有向环。
  debug_inspect(@algo.is_cyclic_directed(g), content="false")
}
```

## 文档

- [`docs/DESIGN.md`](docs/DESIGN.md) —— 架构与设计决策(英文)。
- [`docs/TESTING.md`](docs/TESTING.md) —— 测试方式说明(英文)。
- [`docs/TODO.md`](docs/TODO.md) —— 范围与迁移进度(英文)。

中文文档:

- [`docs/测试文档.md`](docs/测试文档.md) —— 详细测试文档(用例清单、覆盖率、缺陷修复)。
- [`docs/开发报告.md`](docs/开发报告.md) —— 开发报告(目标、设计决策、流程、问题与复现)。

## 许可证

采用 [MIT](LICENSE-MIT) 或 [Apache-2.0](LICENSE-APACHE) 双重许可,与上游 petgraph 保持一致。
