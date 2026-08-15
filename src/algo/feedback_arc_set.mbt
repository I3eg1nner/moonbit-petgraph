///|
/// A node of the working graph built by `greedy_feedback_arc_set`, tracking its
/// current in/out degree as neighbors are removed.
///
/// `prev` / `next` / `in_list` are the intrusive doubly-linked-list position
/// (petgraph stores it in a separate `LinkedListEntry`); `-1` stands for
/// petgraph's `None`.
priv struct FasNode {
  graph_ix : Int
  out_edges : Array[Int]
  in_edges : Array[Int]
  mut out_degree : Int
  mut in_degree : Int
  mut in_list : Bool
  mut prev : Int
  mut next : Int
}

///|
/// The head of one intrusive linked list of `FasNode`s; `start` is `-1` when
/// the list is empty. Nodes live in the shared container, so a list is just a
/// mutable head pointer, as in petgraph's `LinkedList`.
priv struct FasList {
  mut start : Int
}

///|
/// Push `ix` at the front of `list`.
fn FasList::push_front(
  self : FasList,
  ix : Int,
  nodes : Array[FasNode],
) -> Unit {
  if self.start >= 0 {
    nodes[self.start].prev = ix
  }
  let entry = nodes[ix]
  entry.in_list = true
  entry.next = self.start
  entry.prev = -1
  self.start = ix
}

///|
/// Unlink `ix`, which must be a member of `list`.
fn FasList::remove(self : FasList, ix : Int, nodes : Array[FasNode]) -> Unit {
  let entry = nodes[ix]
  let prev = entry.prev
  let next = entry.next
  entry.in_list = false
  entry.prev = -1
  entry.next = -1
  if prev >= 0 {
    nodes[prev].next = next
  }
  if next >= 0 {
    nodes[next].prev = prev
  }
  if self.start == ix {
    self.start = next
  }
}

///|
/// Remove and return the head of `list`, or `-1` when the list is empty.
fn FasList::pop(self : FasList, nodes : Array[FasNode]) -> Int {
  let head = self.start
  if head >= 0 {
    self.remove(head, nodes)
  }
  head
}

///|
/// The bucket structure of the Eades–Lin–Smyth heuristic: sinks/isolated nodes,
/// sources, and bidirectional nodes bucketed by delta degree
/// (`out_degree - in_degree`), positive-or-zero and negative kept apart.
priv struct FasBuckets {
  sinks_or_isolated : FasList
  sources : FasList
  bidirectional_pve_dd : Array[FasList]
  bidirectional_nve_dd : Array[FasList]
}

///|
/// The bucket that `ix` currently belongs in, growing the delta-degree bucket
/// vectors on demand (petgraph's `Buckets::suitable_bucket`).
fn FasBuckets::suitable_bucket(
  self : FasBuckets,
  ix : Int,
  nodes : Array[FasNode],
) -> FasList {
  let node = nodes[ix]
  if node.out_degree == 0 {
    self.sinks_or_isolated
  } else if node.in_degree == 0 {
    self.sources
  } else {
    let delta_degree = node.out_degree - node.in_degree
    if delta_degree >= 0 {
      while self.bidirectional_pve_dd.length() <= delta_degree {
        self.bidirectional_pve_dd.push({ start: -1 })
      }
      self.bidirectional_pve_dd[delta_degree]
    } else {
      let bucket_ix = -delta_degree - 1
      while self.bidirectional_nve_dd.length() <= bucket_ix {
        self.bidirectional_nve_dd.push({ start: -1 })
      }
      self.bidirectional_nve_dd[bucket_ix]
    }
  }
}

///|
/// After `ix` has been moved to the good sequence, re-bucket every neighbor
/// still in a list, decrementing the degree it just lost.
fn FasBuckets::update_neighbour_node_buckets(
  self : FasBuckets,
  ix : Int,
  nodes : Array[FasNode],
) -> Unit {
  for i in 0..<nodes[ix].out_edges.length() {
    let out_ix = nodes[ix].out_edges[i]
    if out_ix == ix {
      continue
    }
    // Ignore nodes which have already been moved to the good sequence.
    if !nodes[out_ix].in_list {
      continue
    }
    self.suitable_bucket(out_ix, nodes).remove(out_ix, nodes)
    // The other node has lost an in-edge; reduce in-degree by 1.
    nodes[out_ix].in_degree = nodes[out_ix].in_degree - 1
    self.suitable_bucket(out_ix, nodes).push_front(out_ix, nodes)
  }
  for i in 0..<nodes[ix].in_edges.length() {
    let in_ix = nodes[ix].in_edges[i]
    if in_ix == ix {
      continue
    }
    if !nodes[in_ix].in_list {
      continue
    }
    self.suitable_bucket(in_ix, nodes).remove(in_ix, nodes)
    // The other node has lost an out-edge; reduce out-degree by 1.
    nodes[in_ix].out_degree = nodes[in_ix].out_degree - 1
    self.suitable_bucket(in_ix, nodes).push_front(in_ix, nodes)
  }
}

///|
/// Drop the empty tail of a bucket vector (petgraph's `trim_bucket_list`).
fn trim_bucket_list(list : Array[FasList]) -> Unit {
  let mut trunc_len = 0
  for i in 0..<list.length() {
    if list[i].start >= 0 {
      trunc_len = i + 1
    }
  }
  list.truncate(trunc_len)
}

///|
/// Compute a "good" linear ordering of the nodes appearing in `edges`, the
/// heart of the greedy feedback-arc-set heuristic.
///
/// Port of petgraph's `good_node_sequence`. Sinks are repeatedly appended to
/// the back of the sequence, sources to the front, and when neither remains the
/// bidirectional node with the highest delta degree is taken as a source.
/// Returns an array mapping node index to sequence position; `-1` marks a node
/// that appears in no edge and therefore in no sequence.
fn good_node_sequence(
  edges : Array[(Int, Int)],
  node_bound : Int,
) -> Array[Int] {
  let nodes : Array[FasNode] = []
  let buckets : FasBuckets = {
    sinks_or_isolated: { start: -1 },
    sources: { start: -1 },
    bidirectional_pve_dd: [],
    bidirectional_nve_dd: [],
  }
  // Lookup of node indices from the input graph to indices into `nodes`.
  let graph_ix_lookup : Map[Int, Int] = Map([])
  fn fas_node_entry(g_ix : Int) -> Int {
    match graph_ix_lookup.get(g_ix) {
      Some(fas_ix) => fas_ix
      None => {
        let fas_ix = nodes.length()
        nodes.push({
          graph_ix: g_ix,
          out_edges: [],
          in_edges: [],
          out_degree: 0,
          in_degree: 0,
          in_list: false,
          prev: -1,
          next: -1,
        })
        graph_ix_lookup[g_ix] = fas_ix
        fas_ix
      }
    }
  }

  // Build node entries.
  for e in edges {
    let from_fas_ix = fas_node_entry(e.0)
    let to_fas_ix = fas_node_entry(e.1)
    nodes[from_fas_ix].out_edges.push(to_fas_ix)
    nodes[to_fas_ix].in_edges.push(from_fas_ix)
  }
  // Set initial in/out-degrees.
  for node in nodes {
    node.out_degree = node.out_edges.length()
    node.in_degree = node.in_edges.length()
  }
  // Add nodes to their initial lists.
  for i in 0..<nodes.length() {
    buckets.suitable_bucket(i, nodes).push_front(i, nodes)
  }
  let s_1 : Array[Int] = [] // built back-to-front order (push_back)
  let s_2_rev : Array[Int] = [] // petgraph pushes to the front; reversed below
  for ;; {
    let mut some_moved = false
    for ;; {
      let sink_fas_ix = buckets.sinks_or_isolated.pop(nodes)
      if sink_fas_ix < 0 {
        break
      }
      some_moved = true
      buckets.update_neighbour_node_buckets(sink_fas_ix, nodes)
      s_2_rev.push(nodes[sink_fas_ix].graph_ix)
    }
    for ;; {
      let source_fas_ix = buckets.sources.pop(nodes)
      if source_fas_ix < 0 {
        break
      }
      some_moved = true
      buckets.update_neighbour_node_buckets(source_fas_ix, nodes)
      s_1.push(nodes[source_fas_ix].graph_ix)
    }
    // Highest delta degree first: scan the positive buckets from the back,
    // then the negative ones from the front (least negative first).
    let mut chosen : FasList? = None
    for i = buckets.bidirectional_pve_dd.length() - 1; i >= 0; i = i - 1 {
      if buckets.bidirectional_pve_dd[i].start >= 0 {
        chosen = Some(buckets.bidirectional_pve_dd[i])
        break
      }
    }
    if chosen is None {
      for list in buckets.bidirectional_nve_dd {
        if list.start >= 0 {
          chosen = Some(list)
          break
        }
      }
    }
    if chosen is Some(list) {
      let highest_dd_fas_ix = list.pop(nodes)
      some_moved = true
      buckets.update_neighbour_node_buckets(highest_dd_fas_ix, nodes)
      s_1.push(nodes[highest_dd_fas_ix].graph_ix)
      trim_bucket_list(buckets.bidirectional_pve_dd)
      trim_bucket_list(buckets.bidirectional_nve_dd)
    }
    if !some_moved {
      break
    }
  }
  let seq = Array::make(node_bound, -1)
  let mut order = 0
  for g_ix in s_1 {
    seq[g_ix] = order
    order = order + 1
  }
  for i = s_2_rev.length() - 1; i >= 0; i = i - 1 {
    seq[s_2_rev[i]] = order
    order = order + 1
  }
  seq
}

///|
/// Find a [feedback arc set](https://en.wikipedia.org/wiki/Feedback_arc_set): a
/// set of edges in the given directed graph which, when removed, make the graph
/// acyclic.
///
/// Uses a greedy heuristic (Eades, Lin & Smyth) to select a small number of
/// edges, but does not necessarily find the *minimum* feedback arc set. Edge
/// and node weights are not considered. Loops (edges to and from the same node)
/// are always included in the returned set.
///
/// Port of petgraph's `algo::greedy_feedback_arc_set`. petgraph returns a lazy
/// iterator of edge references; here the edges are collected into an
/// `Array[EdgeId]`, in ascending edge-index order.
///
/// Time complexity: **O(|V| + |E|)**. Auxiliary space: **O(|V| + |E|)**.
///
/// # Example
/// ```mbt check
/// test {
///   let g : @graph.Graph[Int, Unit] = @graph.from_edges([
///     (0, 1),
///     (1, 2),
///     (2, 3),
///     (3, 4),
///     (4, 5),
///     (5, 0),
///     (4, 1),
///     (1, 3),
///   ])
///   debug_inspect(@algo.is_cyclic_directed(g), content="true")
///   let fas = @algo.greedy_feedback_arc_set(g)
///   // Removing the reported edges breaks every cycle. `remove_edge` swaps the
///   // last edge into the freed slot, so remove from the highest index down.
///   for i = fas.length() - 1; i >= 0; i = i - 1 {
///     g.remove_edge(fas[i]) |> ignore
///   }
///   debug_inspect(@algo.is_cyclic_directed(g), content="false")
/// }
/// ```
pub fn[N, E] greedy_feedback_arc_set(
  g : @graph.Graph[N, E],
) -> Array[@graph.EdgeId] {
  let edge_pairs : Array[(Int, Int)] = []
  for e in g.edge_ids() {
    guard g.edge_endpoints(e) is Some((s, t)) else { continue }
    edge_pairs.push((s.index(), t.index()))
  }
  let node_seq = good_node_sequence(edge_pairs, g.node_count())
  let fas : Array[@graph.EdgeId] = []
  for e in g.edge_ids() {
    guard g.edge_endpoints(e) is Some((s, t)) else { continue }
    // An edge is a back edge (relative to the computed order) exactly when its
    // source is not strictly before its target.
    if node_seq[s.index()] >= node_seq[t.index()] {
      fas.push(e)
    }
  }
  fas
}
