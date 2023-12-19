const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u32;
const ProblemErrors = error{AllocationFailed};

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    var p = Program.init(allocator);
    defer p.deinit();

    var lineIndex: usize = 0;
    while (lines.items[lineIndex].len > 0) : (lineIndex += 1) {
        const line = lines.items[lineIndex];
        const id = before(line, '{');
        var statements = lib.split_str(allocator, between(line, '{', '}'), ",") catch unreachable;
        defer statements.deinit();
        for (statements.items) |s| {
            p.addEntry(id, Statement.parse(s)) catch unreachable;
        }
    }
    lineIndex += 1;
    var res: uint = 0;
    while (lineIndex < lines.items.len) : (lineIndex += 1) {
        const xmas = Xmas.parse(between(lines.items[lineIndex], '{', '}'));
        if (p.accept(xmas)) {
            res += xmas.sumRatings();
        }
    }
    return res;
}

pub fn solve_part_two(lines: std.ArrayList(String)) uint {
    // TODO Process problem input and apply your solver here
    _ = lines;
    return 42;
}

const Command = union(enum) {
    Accept,
    Reject,
    GoTo: String,

    fn parse(symbol: String) Command {
        if (symbol.len == 1 and symbol[0] == 'A') {
            return .Accept;
        } else if (symbol.len == 1 and symbol[0] == 'R') {
            return .Reject;
        } else {
            return .{ .GoTo = symbol };
        }
    }
};

const Operator = enum(u2) {
    Gt,
    Lt,
    Eq,

    fn parse(c: u8) Operator {
        return switch (c) {
            '>' => .Gt,
            '<' => .Lt,
            else => .Eq,
        };
    }

    fn check(self: Operator, left: uint, right: uint) bool {
        return switch (self) {
            .Gt => left > right,
            .Lt => left < right,
            .Eq => left == right,
        };
    }
};

const IfThenElse = struct {
    id: u8,
    op: Operator,
    n: uint,
    ifTrue: Command,

    fn parse(s: String, ifTrue: Command) IfThenElse {
        var op = s[1];
        const n = lib.num_of_string_exn(uint, s[2..]);
        return .{ .id = s[0], .op = Operator.parse(op), .n = n, .ifTrue = ifTrue };
    }
};

const Statement = union(enum) {
    Cmd: Command,
    Condition: IfThenElse,

    fn parse(s: String) Statement {
        const condition = lib.split_n_str(2, s, ":");
        const ifTrueOpt = condition[1];
        if (ifTrueOpt) |ifTrue| {
            return .{ .Condition = IfThenElse.parse(condition[0] orelse unreachable, Command.parse(ifTrue)) };
        } else {
            const symbol = condition[0] orelse unreachable;
            return .{ .Cmd = Command.parse(symbol) };
        }
    }
};

const Xmas = struct {
    x: uint,
    m: uint,
    a: uint,
    s: uint,

    fn parse(s: String) Xmas {
        const split = lib.split_n_str(4, s, ",");
        return .{
            .x = parseItem(split[0] orelse unreachable),
            .m = parseItem(split[1] orelse unreachable),
            .a = parseItem(split[2] orelse unreachable),
            .s = parseItem(split[3] orelse unreachable),
        };
    }

    fn sumRatings(self: Xmas) uint {
        return self.x + self.m + self.a + self.s;
    }

    fn parseItem(s: String) uint {
        const split = lib.split_n_str(2, s, "=");
        return lib.num_of_string_exn(uint, split[1] orelse unreachable);
    }

    fn eval(self: Xmas, id: u8) uint {
        return switch (id) {
            'x' => self.x,
            'm' => self.m,
            'a' => self.a,
            's' => self.s,
            else => unreachable,
        };
    }
};

const ProgramMap = std.StringHashMapUnmanaged(std.ArrayListUnmanaged(Statement));
const Program = struct {
    map: ProgramMap,
    arena: std.heap.ArenaAllocator,

    fn init(allocator: std.mem.Allocator) Program {
        var arena = std.heap.ArenaAllocator.init(allocator);
        var map = ProgramMap{};
        return .{ .arena = arena, .map = map };
    }

    fn addEntry(self: *Program, id: String, statement: Statement) ProblemErrors!void {
        if (self.map.getPtr(id)) |list| {
            list.append(self.arena.allocator(), statement) catch return ProblemErrors.AllocationFailed;
        } else {
            var list = std.ArrayListUnmanaged(Statement){};
            list.append(self.arena.allocator(), statement) catch return ProblemErrors.AllocationFailed;
            self.map.put(self.arena.allocator(), id, list) catch return ProblemErrors.AllocationFailed;
        }
    }

    fn deinit(self: *Program) void {
        self.arena.deinit();
    }

    fn accept(self: Program, xmas: Xmas) bool {
        var currentOpt = self.map.get("in");
        while (currentOpt) |current| {
            st_loop: for (current.items) |statement| {
                switch (statement) {
                    Statement.Cmd => |cmd| switch (cmd) {
                        .Accept => return true,
                        .Reject => return false,
                        .GoTo => |target| {
                            currentOpt = self.map.get(target);
                            break :st_loop;
                        },
                    },
                    Statement.Condition => |ifte| {
                        const idValue = xmas.eval(ifte.id);
                        const ok = ifte.op.check(idValue, ifte.n);
                        if (ok) {
                            switch (ifte.ifTrue) {
                                .Accept => return true,
                                .Reject => return false,
                                .GoTo => |target| {
                                    currentOpt = self.map.get(target);
                                    break :st_loop;
                                },
                            }
                        }
                    },
                }
            }
        }
        return false;
    }
};

fn between(s: String, left: u8, right: u8) String {
    var start: usize = 0;
    while (s[start] != left) : (start += 1) {}
    var end: usize = start + 1;
    while (s[end] != right) : (end += 1) {}
    return s[start + 1 .. end];
}

fn before(s: String, c: u8) String {
    var end: usize = 0;
    while (s[end] != c) : (end += 1) {}
    return s[0..end];
}

// Tests

test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/19.txt", solve_part_one);
    try std.testing.expectEqual(@as(uint, 425811), res);
}

test "Golden Test Part Two" {
    // TODO Test solve_part_two on your actual problem input here
    // You may use for_lines or for_lines_allocating from tests_lib.zig
}

test "Example Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("px{a<2006:qkq,m>2090:A,rfg}");
    try lines.append("pv{a>1716:R,A}");
    try lines.append("lnx{m>1548:A,A}");
    try lines.append("rfg{s<537:gd,x>2440:R,A}");
    try lines.append("qs{s>3448:A,lnx}");
    try lines.append("qkq{x<1416:A,crn}");
    try lines.append("crn{x>2662:A,R}");
    try lines.append("in{s<1351:px,qqz}");
    try lines.append("qqz{s>2770:qs,m<1801:hdj,R}");
    try lines.append("gd{a>3333:R,R}");
    try lines.append("hdj{m>838:A,pv}");
    try lines.append("");
    try lines.append("{x=787,m=2655,a=1222,s=2876}");
    try lines.append("{x=1679,m=44,a=2067,s=496}");
    try lines.append("{x=2036,m=264,a=79,s=2244}");
    try lines.append("{x=2461,m=1339,a=466,s=291}");
    try lines.append("{x=2127,m=1623,a=2188,s=1013}");
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 19114), res);
}

test "Example Part Two" {
    // TODO Test solve_part_two on the problem example here
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    const res = solve_part_two(lines);
    try std.testing.expectEqual(@as(uint, 42), res);
}

test "Parse statement" {
    const input = "x>2662:A";
    const res = Statement.parse(input);
    try std.testing.expectEqual(Statement{ .Condition = IfThenElse{ .id = 'x', .op = Operator.Gt, .n = 2662, .ifTrue = Command.Accept } }, res);
}

test "Parse terminal statement" {
    const id = "abc";
    const accept = "A";
    const reject = "R";

    try std.testing.expectEqualDeep(Statement{ .Cmd = Command{ .GoTo = "abc" } }, Statement.parse(id));
    try std.testing.expectEqual(Statement{ .Cmd = Command.Accept }, Statement.parse(accept));
    try std.testing.expectEqual(Statement{ .Cmd = Command.Reject }, Statement.parse(reject));
}
