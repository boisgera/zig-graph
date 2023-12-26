const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn Graph(comptime Node: type, comptime Weight: type) type {
    return struct {
        const Self = @This();
        const Nodes = std.AutoArrayHashMap(Node, void);
        const Edge = struct { Node, Node };
        const Edges = std.AutoArrayHashMap(Edge, Weight);
        const Path = std.ArrayList(Edge);

        nodes: Nodes,
        edges: Edges,

        pub fn init() Self {
            return Self{
                .nodes = Nodes.init(allocator),
                .edges = Edges.init(allocator),
            };
        }

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = options;
            _ = fmt;
            try writer.print("nodes: ", .{});
            var it_nodes = self.nodes.iterator();
            while (it_nodes.next()) |kv| {
                const node = kv.key_ptr.*;
                try writer.print("{}, ", .{node});
            }
            try writer.print("\n", .{});
            try writer.print("edges: ", .{});
            var it_edges = self.edges.iterator();
            while (it_edges.next()) |kv| {
                const edge = kv.key_ptr.*;
                try writer.print("{} -> {}, ", .{ edge[0], edge[1] });
            }
        }

        pub fn neighbors(graph: Self, node: Node) !Nodes {
            var neighs = Nodes.init(allocator);
            var it = graph.edges.iterator();
            while (it.next()) |kv| {
                const edge = kv.key_ptr.*;
                if (edge[0] == node) {
                    try neighs.put(edge[1], {});
                }
            }
            return neighs;
        }

        const PathInfo = struct {
            path: Path,
            total: Weight,
        };

        const Map = std.AutoHashMap(Node, PathInfo);

        pub fn getMap(graph: Self, src: Node) void {
            var done = Map.init(allocator);
            var todo = Map.init(allocator);
            todo.put(src, .{
                .path = Path.init(allocator).append(src),
                .total = 0,
            });

            var min: Weight = -1;
            var min_path: Path = undefined;
            while (todo.count() != 0) {
                var it_todo = todo.iterator();
                while (it_todo.next()) |node_path| {
                    const node = node_path.key_ptr.*;
                    var path = node_path.key_ptr.*;
                    var it_neighbors = graph.neighbors(node).iterator();
                    while (it_neighbors.next()) |neighbor| {
                        if (!done.contains(neighbor) and !todo.contains(neighbor)) {
                            const total = node.total + graph.get(.{ node, neighbor });
                            if (total < min) {
                                min = total;
                                min_path = path.clone().append(neighbor);
                            }
                        }
                    }
                }
            }

            // Update todo
            const node = min_path.items[min_path.items.len];
            todo.put(node, .{ .path = min_path, .total = min });

            // Study transfer of nodes todo -> done
            var it_todo = todo.iterator();
            while (it_todo.next()) |node_| {
                const it_neighbors = graph.neighbors(node_).iterator();
                var n: ?Node = null;
                while (it_neighbors.next()) |neigh| {
                    if (!todo.contains(neigh) and !done.contains(neigh)) {
                        n = neigh;
                        break;
                    }
                }
                if (n) |_| {} else {
                    const path_info = todo.get(node);
                    done.put(node, path_info);
                }
            }
        }
    };
}
