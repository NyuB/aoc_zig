const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u64;
const ProblemErrors = error{AllocationFailed};

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    var graph = WireGraph.init(allocator);
    defer graph.deinit();
    var wires = Wire.parse(allocator, lines.items) catch unreachable;
    defer wires.deinit();
    graph.addWires(wires.items) catch unreachable;
    for (wires.items, 0..) |wa, a| {
        graph.removeWire(wa);
        defer graph.addWire(wa) catch unreachable;
        for (wires.items, a + 1..) |wb, b| {
            graph.removeWire(wb);
            defer graph.addWire(wb) catch unreachable;
            for (wires.items, b + 1..) |wc, c| {
                _ = c;
                graph.removeWire(wc);
                defer graph.addWire(wc) catch unreachable;
                var components = graph.components(allocator) catch unreachable;
                defer components.deinit();
                if (components.list.items.len == 2) {
                    return @as(uint, components.list.items[0].count() * components.list.items[1].count());
                }
            }
        }
    }

    unreachable;
}

pub fn solve_part_two(lines: std.ArrayList(String)) uint {
    // TODO Process problem input and apply your solver here
    _ = lines;
    return 42;
}

const Wire = struct {
    left: String,
    right: String,

    /// Caller owns returned memory
    fn parse(allocator: std.mem.Allocator, lines: []String) ProblemErrors!std.ArrayList(Wire) {
        var res = std.ArrayList((Wire)).init(allocator);
        errdefer res.deinit();
        for (lines) |l| {
            const originTargets = lib.split_n_str(2, l, ": ");
            const from = originTargets[0] orelse unreachable;
            var to = lib.split_str(allocator, originTargets[1] orelse unreachable, " ") catch return ProblemErrors.AllocationFailed;
            defer to.deinit();
            for (to.items) |t| {
                res.append(Wire{ .left = from, .right = t }) catch return ProblemErrors.AllocationFailed;
            }
        }
        return res;
    }
};

const StringSet = std.StringHashMapUnmanaged(void);
const WireMap = std.StringHashMapUnmanaged(StringSet);

const Components = struct {
    list: std.ArrayListUnmanaged(StringSet),
    arena: std.heap.ArenaAllocator,

    fn init(allocator: std.mem.Allocator) Components {
        var arena = std.heap.ArenaAllocator.init(allocator);
        var list = std.ArrayListUnmanaged(StringSet){};
        return Components{ .list = list, .arena = arena };
    }

    fn deinit(self: *Components) void {
        self.arena.deinit();
    }

    fn startComponent(self: *Components) ProblemErrors!void {
        self.list.append(self.arena.allocator(), StringSet{}) catch return ProblemErrors.AllocationFailed;
    }

    fn addToCurrentComponent(self: *Components, s: String) ProblemErrors!void {
        self.list.items[self.list.items.len - 1].put(self.arena.allocator(), s, {}) catch return ProblemErrors.AllocationFailed;
    }
    fn contains(self: Components, s: String) bool {
        for (self.list.items) |set| {
            if (set.contains(s)) return true;
        }
        return false;
    }
};

const WireGraph = struct {
    map: WireMap,
    arena: std.heap.ArenaAllocator,

    fn init(allocator: std.mem.Allocator) WireGraph {
        var map = WireMap{};
        var arena = std.heap.ArenaAllocator.init(allocator);
        return WireGraph{ .map = map, .arena = arena };
    }

    fn deinit(self: *WireGraph) void {
        self.arena.deinit();
    }

    fn addWires(self: *WireGraph, wires: []Wire) ProblemErrors!void {
        for (wires) |t| {
            try self.addWire(t);
        }
    }

    fn removeWire(self: *WireGraph, wire: Wire) void {
        if (self.map.getPtr(wire.left)) |leftSet| {
            _ = leftSet.remove(wire.right);
        }
        if (self.map.getPtr(wire.right)) |rightSet| {
            _ = rightSet.remove(wire.left);
        }
    }

    fn addWire(self: *WireGraph, wire: Wire) ProblemErrors!void {
        if (self.map.getPtr(wire.left)) |leftSet| {
            leftSet.put(self.arena.allocator(), wire.right, {}) catch return ProblemErrors.AllocationFailed;
        } else {
            var s = StringSet{};
            s.put(self.arena.allocator(), wire.right, {}) catch return ProblemErrors.AllocationFailed;
            self.map.put(self.arena.allocator(), wire.left, s) catch return ProblemErrors.AllocationFailed;
        }

        if (self.map.getPtr(wire.right)) |rightSet| {
            rightSet.put(self.arena.allocator(), wire.left, {}) catch return ProblemErrors.AllocationFailed;
        } else {
            var s = StringSet{};
            s.put(self.arena.allocator(), wire.left, {}) catch return ProblemErrors.AllocationFailed;
            self.map.put(self.arena.allocator(), wire.right, s) catch return ProblemErrors.AllocationFailed;
        }
    }

    /// Caller owns returned memory
    fn components(self: WireGraph, allocator: std.mem.Allocator) ProblemErrors!Components {
        var result = Components.init(allocator);
        var startsIterator = self.map.keyIterator();
        while (startsIterator.next()) |start| {
            if (result.contains(start.*)) continue;
            try result.startComponent();
            try result.addToCurrentComponent(start.*);
            var q = std.ArrayList(String).init(allocator);
            defer q.deinit();
            q.append(start.*) catch return ProblemErrors.AllocationFailed;
            while (q.popOrNull()) |next| {
                if (self.map.get(next)) |neighbours| {
                    var nit = neighbours.keyIterator();
                    while (nit.next()) |n| {
                        if (!result.contains(n.*)) {
                            try result.addToCurrentComponent(n.*);
                            q.append(n.*) catch return ProblemErrors.AllocationFailed;
                        }
                    }
                }
            }
        }

        return result;
    }
};

// Tests

// test "Golden Test Part One" {
//     const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/25.txt", solve_part_one);
//     try std.testing.expectEqual(@as(uint, 0), res);
// }

test "Golden Test Part Two" {
    // TODO Test solve_part_two on your actual problem input here
    // You may use for_lines or for_lines_allocating from tests_lib.zig
}

test "Example Part One" {
    // TODO Test solve_part_one on the problem example here
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("jqt: rhn xhk nvd");
    try lines.append("rsh: frs pzl lsr");
    try lines.append("xhk: hfx");
    try lines.append("cmg: qnr nvd lhk");
    try lines.append("rhn: xhk bvb hfx");
    try lines.append("bvb: xhk hfx");
    try lines.append("pzl: lsr nvd");
    try lines.append("qnr: nvd");
    try lines.append("ntq: jqt hfx bvb xhk");
    try lines.append("nvd: lhk");
    try lines.append("lsr: lhk");
    try lines.append("rzs: qnr cmg lsr rsh");
    try lines.append("frs: qnr lhk lsr");
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 54), res);
}

test "Example Part Two" {
    // TODO Test solve_part_two on the problem example here
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    const res = solve_part_two(lines);
    try std.testing.expectEqual(@as(uint, 42), res);
}

test "Example with three links removed has the expected components" {
    // TODO Test solve_part_one on the problem example here
    var lines = [_]String{
        "jqt: rhn xhk nvd",
        "rsh: frs pzl lsr",
        "xhk: hfx",
        "cmg: qnr nvd lhk",
        "rhn: xhk bvb hfx",
        "bvb: xhk hfx",
        "pzl: lsr nvd",
        "qnr: nvd",
        "ntq: jqt hfx bvb xhk",
        "nvd: lhk",
        "lsr: lhk",
        "rzs: qnr cmg lsr rsh",
        "frs: qnr lhk lsr",
    };
    var graph = WireGraph.init(std.testing.allocator);
    defer graph.deinit();
    var wires = try Wire.parse(std.testing.allocator, &lines);
    defer wires.deinit();
    try graph.addWires(wires.items);

    graph.removeWire(Wire{ .left = "hfx", .right = "pzl" });
    graph.removeWire(Wire{ .left = "bvb", .right = "cmg" });
    graph.removeWire(Wire{ .left = "nvd", .right = "jqt" });

    var components = try graph.components(std.testing.allocator);
    defer components.deinit();
    try std.testing.expectEqual(@as(uint, 2), components.list.items.len);
}
