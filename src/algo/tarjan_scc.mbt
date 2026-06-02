///|
/// Compute the strongly connected components using Tarjan's algorithm.
///
/// Returns a list of SCCs. The order of node ids *within* each SCC is arbitrary,
/// but the SCCs themselves are produced in **reverse topological order**
/// (postorder), matching petgraph's `algo::tarjan_scc` (and `kosaraju_scc`). For
/// an undirected graph the SCCs are the connected components.
///
/// This is an iterative implementation of Tarjan's lowlink algorithm (petgraph
/// uses Pierce's space-efficient recursive variant; both yield the same SCCs in
/// the same reverse-topological order). A component is emitted exactly when its
/// root finishes, and roots finish in reverse topological order, so the emission
/// order matches petgraph without an extra sort.
///
/// # Example
/// ```mbt check
/// test {
///   // {0,1,2} form a cycle (one SCC); node 3 stands alone.
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges([
///     (0, 1),
///     (1, 2),
///     (2, 0),
///     (2, 3),
///   ])
///   let sccs = @algo.tarjan_scc(g)
///   let sizes = sccs.map(fn(c) { c.length() })
///   sizes.sort()
///   debug_inspect(sizes, content="[1, 3]")
/// }
/// ```
pub fn[N, E] tarjan_scc(g : @graph.Graph[N, E]) -> Array[Array[@graph.NodeId]] {
  let n = g.node_count()
  let index = Array::make(n, -1) // discovery index, -1 = undiscovered
  let lowlink = Array::make(n, 0)
  let on_stack = Array::make(n, false)
  let component = []
  let scc_stack : Array[@graph.NodeId] = []
  let mut next_index = 0

  // Explicit work stack of (node, neighbor-cursor) frames replacing recursion.
  for s in 0..<n {
    if index[s] != -1 {
      continue
    }
    let work : Array[(@graph.NodeId, Int)] = [(@graph.NodeId::new(s), 0)]
    while work.last() is Some((v, ci)) {
      let vi = v.index()
      if ci == 0 {
        // First visit of v: assign index/lowlink and push onto the SCC stack.
        index[vi] = next_index
        lowlink[vi] = next_index
        next_index = next_index + 1
        scc_stack.push(v)
        on_stack[vi] = true
      }
      // Materialize: this iterative walk indexes `succs[ci]` and revisits the
      // same successor list across work-stack iterations, so it needs random
      // access, not a single-use `Iter`.
      let succs = g.neighbors_directed(v, Outgoing).to_array()
      if ci < succs.length() {
        // Advance v's cursor and look at the next successor.
        work[work.length() - 1] = (v, ci + 1)
        let w = succs[ci]
        let wi = w.index()
        if index[wi] == -1 {
          work.push((w, 0)) // recurse into w
        } else if on_stack[wi] {
          if index[wi] < lowlink[vi] {
            lowlink[vi] = index[wi]
          }
        }
      } else {
        // Done with v. If it is a root of an SCC, pop the component.
        if lowlink[vi] == index[vi] {
          let scc = []
          while scc_stack.pop() is Some(w) {
            on_stack[w.index()] = false
            scc.push(w)
            if w == v {
              break
            }
          }
          component.push(scc)
        }
        work.pop() |> ignore
        // Propagate lowlink up to the parent (top of work stack after pop).
        if work.last() is Some((p, _)) {
          let pi = p.index()
          if lowlink[vi] < lowlink[pi] {
            lowlink[pi] = lowlink[vi]
          }
        }
      }
    }
  }
  component
}
