const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u64;
const ProblemErrors = error{AllocationFailed};

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    // Read until blank line
    var lineIndex: usize = 0;
    while (lines.items[lineIndex].len > 0) : (lineIndex += 1) {}
    var program = Program.parse(allocator, lines.items[0..lineIndex]) catch unreachable;
    defer program.deinit();

    // Skip blank line
    lineIndex += 1;

    var res: uint = 0;
    while (lineIndex < lines.items.len) : (lineIndex += 1) {
        const xmas = Xmas.parse(between(lines.items[lineIndex], '{', '}'));
        if (program.accept(xmas, "in")) {
            res += xmas.sumRatings();
        }
    }
    return res;
}

pub fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    // Read until blank line
    var lineIndex: usize = 0;
    while (lines.items[lineIndex].len > 0) : (lineIndex += 1) {}
    var program = Program.parse(allocator, lines.items[0..lineIndex]) catch unreachable;
    defer program.deinit();

    const start = XmasSearch.make(Range{ .start = 1, .end = 4001 }, "in", 0);

    return countAcceptable(allocator, program, start) catch unreachable;
}

fn countAcceptable(allocator: std.mem.Allocator, program: Program, searchStart: XmasSearch) ProblemErrors!uint {
    var q = std.ArrayList(XmasSearch).init(allocator);
    defer q.deinit();
    q.append(searchStart) catch return ProblemErrors.AllocationFailed;

    var res: uint = 0;
    while (q.popOrNull()) |xmas| {
        if (xmas.impossible()) continue;
        const entry = program.map.get(xmas.programId) orelse unreachable;
        const statement = entry.items[xmas.programIndex];
        switch (statement) {
            Statement.Cmd => |cmd| switch (cmd) {
                .Accept => res += xmas.combinatory(),
                .Reject => {},
                .GoTo => |target| {
                    q.append(jumpSearchToProgramId(xmas, target)) catch return ProblemErrors.AllocationFailed;
                },
            },
            Statement.Condition => |ifte| {
                var split = switch (ifte.op) {
                    .Gt => xmas.splitGt(ifte.n, ifte.id),
                    .Lt => xmas.splitLt(ifte.n, ifte.id),
                    .Eq => xmas.splitEq(ifte.n, ifte.id),
                };

                switch (ifte.ifTrue) {
                    .Accept => res += split[0].combinatory(),
                    .Reject => {},
                    .GoTo => |target| {
                        q.append(jumpSearchToProgramId(split[0], target)) catch return ProblemErrors.AllocationFailed;
                    },
                }
                split[1].programIndex += 1;
                q.append(split[1]) catch return ProblemErrors.AllocationFailed;
            },
        }
    }
    return res;
}

fn jumpSearchToProgramId(xmas: XmasSearch, id: String) XmasSearch {
    return XmasSearch{ .xRange = xmas.xRange, .mRange = xmas.mRange, .aRange = xmas.aRange, .sRange = xmas.sRange, .programId = id, .programIndex = 0 };
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

    /// Caller must call `deinit` on the result
    fn init(allocator: std.mem.Allocator) Program {
        var arena = std.heap.ArenaAllocator.init(allocator);
        var map = ProgramMap{};
        return .{ .arena = arena, .map = map };
    }

    /// Caller must call `deinit` on the result
    fn parse(allocator: std.mem.Allocator, lines: []const String) ProblemErrors!Program {
        var program = Program.init(allocator);
        for (lines) |line| {
            const id = before(line, '{');
            var statements = lib.split_str(allocator, between(line, '{', '}'), ",") catch return ProblemErrors.AllocationFailed;
            defer statements.deinit();
            for (statements.items) |s| {
                program.addEntry(id, Statement.parse(s)) catch return ProblemErrors.AllocationFailed;
            }
        }
        return program;
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

    fn accept(self: Program, xmas: Xmas, startId: String) bool {
        var currentId = startId;
        while (self.map.get(currentId)) |current| {
            for (current.items) |statement| {
                if (evalStatement(statement, xmas)) |cmd| {
                    switch (cmd) {
                        .Accept => return true,
                        .Reject => return false,
                        .GoTo => |target| {
                            currentId = target;
                            break;
                        },
                    }
                } // else proceed to the 'else branch' => the next statement
            }
        }
        return false;
    }

    /// Returns the command corresponding to `statement` in the `xmas` context or null if the else branch must be evaluated
    fn evalStatement(statement: Statement, xmas: Xmas) ?Command {
        return switch (statement) {
            Statement.Cmd => |cmd| cmd,
            Statement.Condition => |ifte| {
                const idValue = xmas.eval(ifte.id);
                const ok = ifte.op.check(idValue, ifte.n);
                if (ok) {
                    return ifte.ifTrue;
                } else {
                    return null;
                }
            },
        };
    }
};

const Range = struct {
    start: uint,
    end: uint,

    fn splitEq(self: Range, n: uint) [2]Range {
        if (n >= self.start and n < self.end) {
            return [2]Range{ Range{ .start = n, .end = n + 1 }, self.makeEmpty() };
        } else {
            return [2]Range{ self.makeEmpty(), self.makeEmpty() };
        }
    }

    fn splitGt(self: Range, n: uint) [2]Range {
        if (n >= self.end) {
            return [2]Range{ self.makeEmpty(), self };
        } else if (n < self.start) {
            return [2]Range{ self, self.makeEmpty() };
        } else {
            return [2]Range{ Range{ .start = n + 1, .end = self.end }, Range{ .start = self.start, .end = n + 1 } };
        }
    }

    fn splitLt(self: Range, n: uint) [2]Range {
        if (n <= self.start) {
            return [2]Range{ self.makeEmpty(), self };
        } else if (n >= self.end) {
            return [2]Range{ self, self.makeEmpty() };
        } else {
            return [2]Range{ Range{ .start = self.start, .end = n }, Range{ .start = n, .end = self.end } };
        }
    }

    fn empty(self: Range) bool {
        return self.begin >= self.end;
    }

    fn makeEmpty(self: Range) Range {
        return Range{ .start = self.start, .end = self.start };
    }

    fn span(self: Range) uint {
        return self.end - self.start;
    }
};

const XmasSearch = struct {
    xRange: Range,
    mRange: Range,
    aRange: Range,
    sRange: Range,

    programId: String,
    programIndex: usize,

    const InitialRange = Range{ .start = 1, .end = 4001 };

    fn make(initialRange: Range, programId: String, programIndex: usize) XmasSearch {
        return XmasSearch{ .xRange = initialRange, .mRange = initialRange, .aRange = initialRange, .sRange = initialRange, .programId = programId, .programIndex = programIndex };
    }

    fn combinatory(self: XmasSearch) uint {
        return self.xRange.span() * self.mRange.span() * self.aRange.span() * self.sRange.span();
    }

    fn impossible(self: XmasSearch) bool {
        return self.combinatory() == 0;
    }

    fn splitEq(self: XmasSearch, n: uint, id: u8) [2]XmasSearch {
        var copyLeft = self;
        var copyRight = self;
        switch (id) {
            'x' => {
                const split = self.xRange.splitEq(n);
                copyLeft.xRange = split[0];
                copyRight.xRange = split[1];
            },
            'm' => {
                const split = self.mRange.splitEq(n);
                copyLeft.mRange = split[0];
                copyRight.mRange = split[1];
            },
            'a' => {
                const split = self.aRange.splitEq(n);
                copyLeft.aRange = split[0];
                copyRight.aRange = split[1];
            },
            's' => {
                const split = self.sRange.splitEq(n);
                copyLeft.sRange = split[0];
                copyRight.sRange = split[1];
            },
            else => unreachable,
        }
        return [2]XmasSearch{ copyLeft, copyRight };
    }

    fn splitGt(self: XmasSearch, n: uint, id: u8) [2]XmasSearch {
        var copyLeft = self;
        var copyRight = self;
        switch (id) {
            'x' => {
                const split = self.xRange.splitGt(n);
                copyLeft.xRange = split[0];
                copyRight.xRange = split[1];
            },
            'm' => {
                const split = self.mRange.splitGt(n);
                copyLeft.mRange = split[0];
                copyRight.mRange = split[1];
            },
            'a' => {
                const split = self.aRange.splitGt(n);
                copyLeft.aRange = split[0];
                copyRight.aRange = split[1];
            },
            's' => {
                const split = self.sRange.splitGt(n);
                copyLeft.sRange = split[0];
                copyRight.sRange = split[1];
            },
            else => unreachable,
        }
        return [2]XmasSearch{ copyLeft, copyRight };
    }

    fn splitLt(self: XmasSearch, n: uint, id: u8) [2]XmasSearch {
        var copyLeft = self;
        var copyRight = self;
        switch (id) {
            'x' => {
                const split = self.xRange.splitLt(n);
                copyLeft.xRange = split[0];
                copyRight.xRange = split[1];
            },
            'm' => {
                const split = self.mRange.splitLt(n);
                copyLeft.mRange = split[0];
                copyRight.mRange = split[1];
            },
            'a' => {
                const split = self.aRange.splitLt(n);
                copyLeft.aRange = split[0];
                copyRight.aRange = split[1];
            },
            's' => {
                const split = self.sRange.splitLt(n);
                copyLeft.sRange = split[0];
                copyRight.sRange = split[1];
            },
            else => unreachable,
        }
        return [2]XmasSearch{ copyLeft, copyRight };
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
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/19.txt", solve_part_two);
    try std.testing.expectEqual(@as(uint, 131796824371749), res);
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
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 167409079868000), res);
}

test "Only one value possible" {
    const lines = [_]String{"in{x>1:R,m>1:R,a>1:R,s<2:A,R}"};
    var program = try Program.parse(std.testing.allocator, &lines);
    defer program.deinit();
    const searchStart = XmasSearch.make(Range{ .start = 1, .end = 3 }, "in", 0);
    const res = try countAcceptable(std.testing.allocator, program, searchStart);
    try std.testing.expectEqual(@as(uint, 1), res);
}

test "Multiple possible values" {
    const lines = [_]String{"in{x>2:R,m>1:R,a>1:R,s<4:A,R}"};
    var program = try Program.parse(std.testing.allocator, &lines);
    defer program.deinit();
    const searchStart = XmasSearch.make(Range{ .start = 1, .end = 5 }, "in", 0);
    const res = try countAcceptable(std.testing.allocator, program, searchStart);
    try std.testing.expectEqual(@as(uint, 6), res);
}

test "With jump" {
    const lines = [_]String{
        "in{x>1:reject,accept}",
        "accept{A}",
        "reject{R}",
    };
    var program = try Program.parse(std.testing.allocator, &lines);
    defer program.deinit();
    const searchStart = XmasSearch.make(Range{ .start = 1, .end = 3 }, "in", 0);
    const res = try countAcceptable(std.testing.allocator, program, searchStart);
    try std.testing.expectEqual(@as(uint, 8), res);
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

test "Range splits" {
    const r = Range{ .start = 1, .end = 4001 };
    const splitGt = r.splitGt(2);
    try std.testing.expectEqual(Range{ .start = 3, .end = 4001 }, splitGt[0]);
    try std.testing.expectEqual(@as(uint, 3998), splitGt[0].span());
    try std.testing.expectEqual(Range{ .start = 1, .end = 3 }, splitGt[1]);
    try std.testing.expectEqual(@as(uint, 2), splitGt[1].span());
}
