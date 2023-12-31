const std = @import("std");
const assert = std.debug.assert;
const panic = std.debug.panic;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const sec = 1_000_000_000;

// TODO: can we infer K and V from the type of set?
pub fn displaySet(comptime K: type, comptime V: type, set: std.AutoHashMap(K, V)) void {
    var key_it = set.keyIterator();

    while (key_it.next()) |key| {
        std.debug.print("{}, ", .{key.*});
    }
    std.debug.print("\n", .{});
}

// All I want is a smart display for Path, I feel that this wrapping is
// a bit too much. I could make a wrapper post-hoc, on the fly?
pub fn Path(comptime Node: type) type {
    return struct {
        const Self = @This();
        nodes: std.ArrayList(Node),

        pub fn init(allocator_: std.mem.Allocator) Self {
            return .{ .nodes = std.ArrayList(Node).init(allocator_) };
        }

        pub fn deinit(self: Self) void {
            self.nodes.deinit();
        }

        pub fn clone(self: Self) !Self {
            var other = Self.init(self.nodes.allocator);
            other.nodes = try self.nodes.clone();
            return other;
        }

        pub fn format(
            self: Self,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            var first: bool = true;
            try writer.print("(", .{});
            for (self.nodes.items) |node| {
                if (first) {
                    try writer.print("{}", .{node});
                    first = false;
                } else {
                    try writer.print(" -> {}", .{node});
                }
            }
            try writer.print(")", .{});
        }
    };
}

pub fn Graph(comptime Node: type, comptime Weight: type) type {
    return struct {
        const Self = @This();
        const Nodes = std.AutoHashMap(Node, void);
        const Edge = struct { Node, Node };
        const Edges = std.AutoHashMap(Edge, Weight);

        nodes: Nodes,
        edges: Edges,

        pub fn init() Self {
            return Self{
                .nodes = Nodes.init(allocator),
                .edges = Edges.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.nodes.deinit();
            self.edges.deinit();
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

        // TODO: precompute neighbors? Panic on the allocation error?
        //       cache the result?
        pub fn neighbors(graph: Self, node: Node) Nodes {
            var neighs = Nodes.init(allocator);
            var it = graph.edges.iterator();
            while (it.next()) |kv| {
                const edge = kv.key_ptr.*;
                if (edge[0] == node) {
                    neighs.put(edge[1], {}) catch std.debug.panic("OOM", .{});
                }
            }
            return neighs;
        }

        const PathInfo = struct {
            path: Path(Node),
            total: Weight,
        };

        const Map = std.AutoHashMap(Node, PathInfo);

        pub fn getMap(graph: Self, src: Node) !Map {
            var done = Map.init(allocator);

            var todo = Map.init(allocator);
            defer todo.deinit();
            var src_path = Path(Node).init(allocator);
            try src_path.nodes.append(src);
            try todo.put(src, .{
                .path = src_path,
                .total = 0,
            });

            while (todo.count() != 0) {
                std.debug.print("------------------\n", .{});
                std.time.sleep(3 * sec);
                std.debug.print("todo count: {}\n", .{todo.count()});

                var min: Weight = 999999;
                var min_path: Path(Node) = undefined;
                var min_neighbor: Node = undefined;
                std.debug.print("min_node: {}\n", .{min_neighbor});

                var it_todo = todo.iterator();
                while (it_todo.next()) |node_path| {
                    std.debug.print("* todo loop\n", .{});
                    const node = node_path.key_ptr.*;
                    var path_info = node_path.value_ptr.*;
                    std.debug.print("node picked in todo: {}\n", .{node});
                    var it_neighbors = graph.neighbors(node).iterator();
                    while (it_neighbors.next()) |nkv| {
                        const neighbor = nkv.key_ptr.*;
                        std.debug.print("neighbor: {}\n", .{neighbor});
                        if (!done.contains(neighbor) and !todo.contains(neighbor)) {
                            std.debug.print("neighbor to consider\n", .{});
                            var total = if (todo.get(node)) |path_info_| path_info_.total else unreachable;
                            std.debug.print("total before {}\n", .{total});
                            total += if (graph.edges.get(.{ node, neighbor })) |w| w else unreachable;
                            std.debug.print("total after {}\n", .{total});
                            if (total < min) {
                                std.debug.print("smaller than {}\n", .{min});
                                min = total;
                                min_neighbor = neighbor;
                                min_path = try path_info.path.clone();
                                try min_path.nodes.append(neighbor);
                            }
                        }
                    }
                }
                // Update todo
                std.debug.print("min_neighbor: {}\n", .{min_neighbor});
                try todo.put(min_neighbor, .{ .path = min_path, .total = min });
                try graph.transferIfDone(&todo, &done);
            }
            return done;
        }

        fn transferIfDone(graph: Self, todo: *Map, done: *Map) !void {
            std.debug.print("transfer\n", .{});

            std.debug.print("todo: ", .{});
            displaySet(Node, PathInfo, todo.*);
            std.debug.print("done: ", .{});
            displaySet(Node, PathInfo, done.*);

            const todo_clone = todo.clone() catch std.debug.panic("OOM", .{});
            var todo_clone_it = todo_clone.iterator();
            while (todo_clone_it.next()) |node_pathinfo| {
                const node = node_pathinfo.key_ptr.*;
                const path_info = node_pathinfo.value_ptr.*;

                var it_neighbors = graph.neighbors(node).keyIterator();
                var new_neighbor: ?Node = null;
                while (it_neighbors.next()) |neighbor| {
                    const n = neighbor.*;
                    if (!todo.contains(n) and !done.contains(n)) {
                        new_neighbor = n;
                        break;
                    }
                }

                if (new_neighbor == null) { // every neighbor already tracked
                    assert(todo.remove(node) == true);
                    assert(done.remove(node) == false);
                    try done.put(node, path_info);
                }
            }

            std.debug.print("todo: ", .{});
            displaySet(Node, PathInfo, todo.*);
            std.debug.print("done: ", .{});
            displaySet(Node, PathInfo, done.*);
        }
    };
}
