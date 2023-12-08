const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;

fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) u32 {
    var instructions = parseDirections(allocator, lines.items[0]) catch unreachable;
    defer instructions.deinit();
    var btree = BTree.parse(allocator, lines.items[2..]) catch unreachable;
    defer btree.deinit();
    return btree.distanceFollowingInstructions(instructions.items, "AAA", isZZZ) orelse unreachable;
}

fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) u32 {
    var instructions = parseDirections(allocator, lines.items[0]) catch unreachable;
    defer instructions.deinit();
    var btree = BTree.parse(allocator, lines.items[2..]) catch unreachable;
    defer btree.deinit();
    var origins = std.ArrayList(String).init(allocator);
    defer origins.deinit();
    var res: u32 = 0;
    _ = res;
    var starts = btree.map.keyIterator();
    while (starts.next()) |start| {
        if (endsWithA(start.*)) {
            origins.append(start.*) catch unreachable;
        }
    }
    return btree.parallelDistanceFollowingInstructions(allocator, instructions.items, origins.items, endsWithZ) orelse unreachable;
}

const Direction = enum { Left, Right };
fn parseDirections(allocator: std.mem.Allocator, s: String) !std.ArrayList(Direction) {
    var res = std.ArrayList(Direction).init(allocator);
    errdefer res.deinit();
    for (s) |c| {
        if (c == 'L') try res.append(Direction.Left);
        if (c == 'R') try res.append(Direction.Right);
    }
    return res;
}

fn endsWithA(s: String) bool {
    if (s.len == 0) return false;
    return s[s.len - 1] == 'A';
}

fn endsWithZ(s: String) bool {
    if (s.len == 0) return false;
    return s[s.len - 1] == 'Z';
}

fn isZZZ(s: String) bool {
    return std.mem.eql(u8, s, "ZZZ");
}

const BTree = struct {
    map: std.StringHashMap(BTreeNode),
    fn deinit(self: *BTree) void {
        self.map.deinit();
    }

    fn distanceFollowingInstructions(self: BTree, instructions: []Direction, origin: String, Predicate: *const fn (String) bool) ?u32 {
        var res: u32 = 0;
        var current = origin;
        var cycle = InstructionCycle.init(instructions);
        while (cycle.next()) |direction| {
            if (Predicate(current)) {
                return res;
            }
            const node = self.map.get(current) orelse return null;
            current = switch (direction) {
                .Left => node.left,
                .Right => node.right,
            };
            res += 1;
        }
        return null; // We should have return from inside the loop or there is a problem with the instructions
    }

    fn parallelDistanceFollowingInstructions(self: BTree, allocator: std.mem.Allocator, instructions: []Direction, origins: []String, Predicate: *const fn (String) bool) ?u32 {
        var res: u32 = 0;
        var currents = allocator.alloc(String, origins.len) catch return null;
        defer allocator.free(currents);
        std.mem.copy(String, currents, origins);
        var cycle = InstructionCycle.init(instructions);
        var allAligned = false;
        while (!allAligned) {
            allAligned = true;
            var nextDirection = cycle.next() orelse return null;
            for (currents, 0..) |current, index| {
                allAligned = allAligned and Predicate(current);
                const node = self.map.get(current) orelse return null;
                currents[index] = switch (nextDirection) {
                    .Left => node.left,
                    .Right => node.right,
                };
            }

            if (!allAligned) {
                res += 1;
            }
        }
        return res;
    }

    const ParseError = error{ AllocationError, InvalidLineFormat };

    fn parse(allocator: std.mem.Allocator, lines: []String) ParseError!BTree {
        var map = std.StringHashMap(BTreeNode).init(allocator);
        errdefer map.deinit();
        for (lines) |l| {
            const origin_node = lib.split_n_str(2, l, " = ");
            const origin = origin_node[0] orelse return ParseError.InvalidLineFormat;
            const leftRightPar = lib.split_n_str(2, origin_node[1] orelse return ParseError.InvalidLineFormat, ", ");
            const left = (leftRightPar[0] orelse return ParseError.InvalidLineFormat)[1..];
            const rightPar = leftRightPar[1] orelse return ParseError.InvalidLineFormat;
            const right = rightPar[0 .. rightPar.len - 1];
            map.put(origin, BTreeNode{ .left = left, .right = right }) catch return ParseError.AllocationError;
        }
        return BTree{ .map = map };
    }
};
const BTreeNode = struct {
    left: String,
    right: String,
};

const InstructionCycle = struct {
    instructions: []const Direction,
    current: usize,

    fn init(instructions: []const Direction) InstructionCycle {
        return InstructionCycle{ .instructions = instructions, .current = 0 };
    }

    fn next(self: *InstructionCycle) ?Direction {
        if (self.instructions.len == 0) return null;
        defer self.inc();
        return self.instructions[self.current];
    }

    fn inc(self: *InstructionCycle) void {
        self.current = (self.current + 1) % self.instructions.len;
    }
};

// Tests

test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(u32, std.testing.allocator, "problems/08.txt", solve_part_one);
    try std.testing.expectEqual(@as(u32, 20093), res);
}
// test "Golden Test Part Two" {
//     const res = try lib.for_lines_allocating(u32, std.testing.allocator, "problems/08.txt", solve_part_two);
//     try std.testing.expectEqual(@as(u32, 0), res);
// }

test "Example Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("RL");
    try lines.append("");
    try lines.append("AAA = (BBB, CCC)");
    try lines.append("BBB = (DDD, EEE)");
    try lines.append("CCC = (ZZZ, GGG)");
    try lines.append("DDD = (DDD, DDD)");
    try lines.append("EEE = (EEE, EEE)");
    try lines.append("GGG = (GGG, GGG)");
    try lines.append("ZZZ = (ZZZ, ZZZ)");
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(u32, 2), res);
}

test "Example Part One cyclic required" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("LLR");
    try lines.append("");
    try lines.append("AAA = (BBB, BBB)");
    try lines.append("BBB = (AAA, ZZZ)");
    try lines.append("ZZZ = (ZZZ, ZZZ)");
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(u32, 6), res);
}

test "Example Part Two" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("LR");
    try lines.append("");
    try lines.append("11A = (11B, XXX)");
    try lines.append("11B = (XXX, 11Z)");
    try lines.append("11Z = (11B, XXX)");
    try lines.append("22A = (22B, XXX)");
    try lines.append("22B = (22C, 22C)");
    try lines.append("22C = (22Z, 22Z)");
    try lines.append("22Z = (22B, 22B)");
    try lines.append("XXX = (XXX, XXX)");
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(u32, 6), res);
}

test "Cyclic instructions" {
    var iterationCount: u32 = 0;
    const instructions = [_]Direction{ Direction.Left, Direction.Left, Direction.Left };
    var it = InstructionCycle.init(&instructions);
    while (it.next()) |_| {
        iterationCount += 1;
        if (iterationCount == 42) break;
    }
    try expect(iterationCount == 42);
}
