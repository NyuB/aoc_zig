const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u32;
const ProblemErrors = error{AllocationFailed};

fn solve_part_one(lines: std.ArrayList(String)) uint {
    var res: uint = 0;
    const singleLine = lines.items[0];
    var hash = HASH.init();
    for (singleLine) |c| {
        if (c == '\n' or c == '\r') continue;
        if (c == ',') {
            res += hash.end();
            hash = HASH.init();
        } else {
            hash.updateChar(c);
        }
    }
    return res + hash.end();
}

fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    var split = lib.split_str(allocator, lines.items[0], ",") catch unreachable;
    defer split.deinit();

    var map = HASHMAP.init(allocator);
    defer map.deinit();

    for (split.items) |instruction| {
        switch (Instruction.parse(instruction)) {
            .Update => |l| {
                map.update(l.label, l.focal) catch unreachable;
            },
            .Del => |label| {
                map.del(label);
            },
        }
    }
    return score(map);
}

const HASH = struct {
    state: uint,

    fn init() HASH {
        return HASH{ .state = 0 };
    }

    inline fn update(self: *HASH, data: []const u8) void {
        for (data) |c| {
            self.updateChar(c);
        }
    }

    inline fn updateChar(self: *HASH, c: u8) void {
        self.state += c;
        self.state *= 17;
        self.state %= 256;
    }

    fn end(self: HASH) uint {
        return self.state;
    }

    fn hash(s: String) uint {
        var h = init();
        h.update(s);
        return h.end();
    }
};

const HASHMAP = struct {
    allocator: std.mem.Allocator,
    boxes: [256]std.ArrayListUnmanaged(Lense),

    fn init(allocator: std.mem.Allocator) HASHMAP {
        var boxes: [256]std.ArrayListUnmanaged(Lense) = undefined;
        for (0..256) |i| {
            boxes[i] = std.ArrayListUnmanaged(Lense){};
        }
        return HASHMAP{ .boxes = boxes, .allocator = allocator };
    }

    fn del(self: *HASHMAP, label: String) void {
        const boxIndex: usize = @intCast(HASH.hash(label));

        var lenseIndex: ?usize = null;
        for (self.boxes[boxIndex].items, 0..) |l, i| {
            if (std.mem.eql(u8, label, l.label)) {
                lenseIndex = i;
                break;
            }
        }
        if (lenseIndex) |i| {
            _ = self.boxes[boxIndex].orderedRemove(i);
        }
    }

    fn update(self: *HASHMAP, label: String, focal: uint) ProblemErrors!void {
        const boxIndex = HASH.hash(label);
        for (self.boxes[boxIndex].items) |*l| {
            if (std.mem.eql(u8, label, l.label)) {
                l.focal = focal;
                return;
            }
        }
        self.boxes[boxIndex].append(self.allocator, Lense{ .label = label, .focal = focal }) catch return ProblemErrors.AllocationFailed;
    }

    fn deinit(self: *HASHMAP) void {
        for (&(self.boxes)) |*b| {
            b.deinit(self.allocator);
        }
    }
};

fn score(map: HASHMAP) uint {
    var res: uint = 0;
    for (map.boxes, 0..) |b, i| {
        res += boxScore(i, b.items);
    }
    return res;
}

fn boxScore(boxIndex: usize, box: []Lense) uint {
    var res: uint = 0;
    for (box, 0..) |l, i| {
        res += lib.uint_of_usize(uint, (boxIndex + 1) * (i + 1)) * (l.focal);
    }
    return res;
}

const Lense = struct {
    focal: uint,
    label: String,
};

const Instruction = union(enum) {
    Del: String,
    Update: Lense,

    fn parse(s: String) Instruction {
        const eq = lib.split_n_str(2, s, "=");
        if (eq[1]) |focalStr| {
            const focal = lib.num_of_string_exn(uint, focalStr);
            return Instruction{ .Update = Lense{ .label = eq[0] orelse unreachable, .focal = focal } };
        }

        const minus = lib.split_n_str(2, s, "-");
        return Instruction{ .Del = minus[0] orelse unreachable };
    }
};

// Tests

test "Golden Test Part One" {
    const res = try lib.for_lines(uint, "problems/15.txt", solve_part_one);
    try std.testing.expectEqual(@as(uint, 510013), res);
}

test "Golden Test Part Two" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/15.txt", solve_part_two);
    try std.testing.expectEqual(@as(uint, 268497), res);
}

test "Example Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("rn=1,cm-,qp=3,cm=2,qp-,pc=4,ot=9,ab=5,pc-,pc=6,ot=7");
    const res = solve_part_one(lines);
    try std.testing.expectEqual(@as(uint, 1320), res);
}

test "Example Part Two" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("rn=1,cm-,qp=3,cm=2,qp-,pc=4,ot=9,ab=5,pc-,pc=6,ot=7");
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 145), res);
}

test "HASH" {
    try std.testing.expectEqual(@as(uint, 30), HASH.hash("rn=1"));
    try std.testing.expectEqual(@as(uint, 253), HASH.hash("cm-"));
    try std.testing.expectEqual(@as(uint, 97), HASH.hash("qp=3"));
}

test "HASHMAP" {
    var map = HASHMAP.init(std.testing.allocator);
    defer map.deinit();

    try map.update("rn", 1);
    try expectEqualLenses(map.boxes[0].items[0], Lense{ .focal = 1, .label = "rn" });

    map.del("cm");
    try map.update("qp", 3);
    try expectEqualLenses(map.boxes[1].items[0], Lense{ .focal = 3, .label = "qp" });

    try map.update("cm", 2);
    map.del("qp");
    try std.testing.expectEqual(@as(usize, 0), map.boxes[1].items.len);

    try map.update("pc", 4);
    try std.testing.expectEqual(map.boxes[3].items[0], Lense{ .focal = 4, .label = "pc" });

    try map.update("ot", 9);
    try std.testing.expectEqual(map.boxes[3].items[0], Lense{ .focal = 4, .label = "pc" });
    try std.testing.expectEqual(map.boxes[3].items[1], Lense{ .focal = 9, .label = "ot" });

    try map.update("ab", 5);
    try std.testing.expectEqual(map.boxes[3].items[0], Lense{ .focal = 4, .label = "pc" });
    try std.testing.expectEqual(map.boxes[3].items[1], Lense{ .focal = 9, .label = "ot" });
    try std.testing.expectEqual(map.boxes[3].items[2], Lense{ .focal = 5, .label = "ab" });

    map.del("pc");
    try std.testing.expectEqual(map.boxes[3].items[0], Lense{ .focal = 9, .label = "ot" });
    try std.testing.expectEqual(map.boxes[3].items[1], Lense{ .focal = 5, .label = "ab" });
}

fn expectEqualLenses(a: Lense, b: Lense) !void {
    try std.testing.expectEqual(a.focal, b.focal);
    try std.testing.expectEqualStrings(a.label, b.label);
}
