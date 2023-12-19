const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u32;
const ProblemErrors = error{AllocationFailed};

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    var moves = std.ArrayList(DirectionMove).init(allocator);
    defer moves.deinit();
    var scan = DimensionScan{};

    for (lines.items) |line| {
        const move = DirectionMove.parse(line);
        moves.append(move) catch unreachable;
        scan.move(move);
    }

    var grid = Grid(u8).init(allocator, scan.maxRow + 1, scan.maxCol + 1, '+') catch unreachable;
    defer grid.deinit();
    scan = DimensionScan{ .current = scan.shift };

    for (moves.items) |m| {
        scan.moveSet(u8, &grid, '#', m);
    }

    for (0..grid.rows) |i| {
        if (grid.get(i, 0) == '+') {
            grid.fillFrom(Position{ .i = i, .j = 0 }, '.', isHash) catch unreachable;
        }
        if (grid.get(i, grid.cols - 1) == '+') {
            grid.fillFrom(Position{ .i = i, .j = grid.cols - 1 }, '.', isHash) catch unreachable;
        }
    }

    for (0..grid.cols) |j| {
        if (grid.get(0, j) == '+') {
            grid.fillFrom(Position{ .i = 0, .j = j }, '.', isHash) catch unreachable;
        }
        if (grid.get(grid.rows - 1, j) == '+') {
            grid.fillFrom(Position{ .i = grid.rows - 1, .j = j }, '.', isHash) catch unreachable;
        }
    }

    var res: uint = 0;
    for (0..grid.rows) |i| {
        for (0..grid.cols) |j| {
            if (grid.get(i, j) != '.') {
                res += 1;
            }
        }
    }

    return res;
}

pub fn solve_part_two(lines: std.ArrayList(String)) uint {
    // TODO Process problem input and apply your solver here
    _ = lines;
    return 42;
}

const DimensionScan = struct {
    current: Position = Position{ .i = 0, .j = 0 },
    shift: Position = Position{ .i = 0, .j = 0 },
    maxRow: usize = 0,
    maxCol: usize = 0,

    fn move(self: *DimensionScan, m: DirectionMove) void {
        var pos = self.current;
        for (0..m.amount) |_| {
            if (m.direction == Direction.Left and pos.j == 0) {
                self.shift.j += 1;
                self.maxCol += 1;
                pos.j += 1;
            }
            if (m.direction == Direction.Up and pos.i == 0) {
                self.shift.i += 1;
                self.maxRow += 1;
                pos.i += 1;
            }
            pos = m.direction.next(pos);
        }
        self.setCurrentPosition(pos);
    }

    fn moveSet(self: *DimensionScan, comptime T: type, grid: *Grid(T), item: T, m: DirectionMove) void {
        var pos = self.current;
        grid.setAt(pos, item);
        for (0..m.amount) |_| {
            pos = m.direction.next(pos);
            grid.setAt(pos, item);
        }
        self.setCurrentPosition(pos);
    }

    fn setCurrentPosition(self: *DimensionScan, pos: Position) void {
        self.maxRow = @max(pos.i, self.maxRow);
        self.maxCol = @max(pos.j, self.maxCol);
        self.current = pos;
    }
};

const DirectionMove = struct {
    direction: Direction,
    amount: usize,

    fn parse(line: String) DirectionMove {
        const trio = lib.split_n_str(3, line, " ");
        const direction = Direction.parse((trio[0] orelse unreachable)[0]);
        const amount = lib.num_of_string_exn(usize, trio[1] orelse unreachable);
        return .{ .direction = direction, .amount = amount };
    }
};

fn Grid(comptime T: type) type {
    return struct {
        items: []T,
        rows: usize,
        cols: usize,
        allocator: std.mem.Allocator,

        const Self = @This();
        fn get(self: Self, i: usize, j: usize) T {
            return self.items[i * self.cols + j];
        }

        fn getAt(self: Self, pos: Position) T {
            return self.get(pos.i, pos.j);
        }

        fn set(self: *Self, i: usize, j: usize, item: T) void {
            self.items[i * self.cols + j] = item;
        }

        fn setAt(self: *Self, pos: Position, item: T) void {
            self.set(pos.i, pos.j, item);
        }

        fn init(allocator: std.mem.Allocator, rows: usize, cols: usize, item: T) ProblemErrors!Self {
            var items = allocator.alloc(T, rows * cols) catch return ProblemErrors.AllocationFailed;
            for (0..rows) |i| {
                for (0..cols) |j| {
                    items[i * cols + j] = item;
                }
            }
            return Self{ .items = items, .rows = rows, .cols = cols, .allocator = allocator };
        }

        fn fillFrom(self: *Self, pos: Position, item: T, isBlocker: *const fn (T) bool) ProblemErrors!void {
            var check = try Grid(bool).init(self.allocator, self.rows, self.cols, false);
            defer check.deinit();
            var q = std.ArrayList(Position).init(self.allocator);
            defer q.deinit();
            q.append(pos) catch return ProblemErrors.AllocationFailed;
            while (q.popOrNull()) |p| {
                check.setAt(p, true);
                self.setAt(p, item);
                if (p.i > 0 and !isBlocker(self.get(p.i - 1, p.j)) and !check.get(p.i - 1, p.j)) {
                    const next = Direction.up(p);
                    check.setAt(next, true);
                    q.append(next) catch return ProblemErrors.AllocationFailed;
                }
                if (p.i < self.rows - 1 and !isBlocker(self.get(p.i + 1, p.j)) and !check.get(p.i + 1, p.j)) {
                    const next = Direction.down(p);
                    check.setAt(next, true);
                    q.append(next) catch return ProblemErrors.AllocationFailed;
                }
                if (p.j > 0 and !isBlocker(self.get(p.i, p.j - 1)) and !check.get(p.i, p.j - 1)) {
                    const next = Direction.left(p);
                    check.setAt(next, true);
                    q.append(next) catch return ProblemErrors.AllocationFailed;
                }
                if (p.j < self.cols - 1 and !isBlocker(self.get(p.i, p.j + 1)) and !check.get(p.i, p.j + 1)) {
                    const next = Direction.right(p);
                    check.setAt(next, true);
                    q.append(next) catch return ProblemErrors.AllocationFailed;
                }
            }
        }

        fn deinit(self: *Self) void {
            self.allocator.free(self.items);
        }
    };
}

fn isHash(c: u8) bool {
    return c == '#';
}

const Direction = union(enum(u2)) {
    Left = 0,
    Up = 1,
    Right = 2,
    Down = 3,

    fn next(self: Direction, pos: Position) Position {
        return switch (self) {
            .Left => Position{ .i = pos.i, .j = pos.j - 1 },
            .Right => Position{ .i = pos.i, .j = pos.j + 1 },
            .Up => Position{ .i = pos.i - 1, .j = pos.j },
            .Down => Position{ .i = pos.i + 1, .j = pos.j },
        };
    }

    fn left(pos: Position) Position {
        const n = Direction{ .Left = {} };
        return n.next(pos);
    }
    fn up(pos: Position) Position {
        const n = Direction{ .Up = {} };
        return n.next(pos);
    }
    fn right(pos: Position) Position {
        const n = Direction{ .Right = {} };
        return n.next(pos);
    }
    fn down(pos: Position) Position {
        const n = Direction{ .Down = {} };
        return n.next(pos);
    }

    fn parse(c: u8) Direction {
        return switch (c) {
            'L' => .Left,
            'U' => .Up,
            'R' => .Right,
            'D' => .Down,
            else => unreachable,
        };
    }
};

const Position = struct {
    i: usize,
    j: usize,
};

// Tests
test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/18.txt", solve_part_one);
    try std.testing.expectEqual(@as(uint, 52055), res);
}

test "Golden Test Part Two" {
    // TODO Test solve_part_two on your actual problem input here
    // You may use for_lines or for_lines_allocating from tests_lib.zig
}

test "Example Part One" {
    // TODO Test solve_part_one on the problem example here
    var lines = std.ArrayList(String).init(std.testing.allocator);
    try lines.append("R 6 (#70c710)");
    try lines.append("D 5 (#0dc571)");
    try lines.append("L 2 (#5713f0)");
    try lines.append("D 2 (#d2c081)");
    try lines.append("R 2 (#59c680)");
    try lines.append("D 2 (#411b91)");
    try lines.append("L 5 (#8ceee2)");
    try lines.append("U 2 (#caa173)");
    try lines.append("L 1 (#1b58a2)");
    try lines.append("U 2 (#caa171)");
    try lines.append("R 2 (#7807d2)");
    try lines.append("U 3 (#a77fa3)");
    try lines.append("L 2 (#015232)");
    try lines.append("U 2 (#7a21e3)");
    defer lines.deinit();
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 62), res);
}

test "Example Part Two" {
    // TODO Test solve_part_two on the problem example here
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    const res = solve_part_two(lines);
    try std.testing.expectEqual(@as(uint, 42), res);
}
