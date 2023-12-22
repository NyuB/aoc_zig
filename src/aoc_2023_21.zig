const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u32;
const ProblemErrors = error{AllocationFailed};

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    for (lines.items, 0..) |row, i| {
        for (row, 0..) |c, j| {
            if (c == 'S') {
                var grid = DistanceGrid.init(allocator, lines.items, lines.items.len, lines.items[0].len, i, j) catch unreachable;
                defer grid.deinit();
                return solve(grid, 64);
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

fn solve(grid: DistanceGrid, steps: uint) uint {
    var res: uint = 0;
    for (0..grid.rows) |i| {
        for (0..grid.cols) |j| {
            if (grid.get(i, j)) |dist| {
                if (dist % 2 == steps % 2 and dist <= steps) {
                    res += 1;
                }
            }
        }
    }
    return res;
}

const DistanceGrid = struct {
    grid: []?uint,
    rows: usize,
    cols: usize,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, map: []const String, rows: usize, cols: usize, startRow: usize, startCol: usize) ProblemErrors!DistanceGrid {
        var grid = allocator.alloc(?uint, rows * cols) catch return ProblemErrors.AllocationFailed;
        for (0..grid.len) |i| {
            grid[i] = null;
        }
        var res = DistanceGrid{ .grid = grid, .rows = rows, .cols = cols, .allocator = allocator };
        res.set(startRow, startCol, 0);

        var q = std.fifo.LinearFifo(Position, std.fifo.LinearFifoBufferType.Dynamic).init(allocator);
        defer q.deinit();
        q.writeItem(Position{ .i = startRow, .j = startCol }) catch return ProblemErrors.AllocationFailed;
        while (q.readItem()) |pos| {
            if (pos.i > 0) {
                const up = Position{ .i = pos.i - 1, .j = pos.j };
                if (res.getAt(up) == null and map[up.i][up.j] != '#') {
                    res.setAt(up, (res.getAt(pos) orelse unreachable) + 1);
                    q.writeItem(up) catch return ProblemErrors.AllocationFailed;
                }
            }
            if (pos.i < rows - 1) {
                const down = Position{ .i = pos.i + 1, .j = pos.j };
                if (res.getAt(down) == null and map[down.i][down.j] != '#') {
                    res.setAt(down, (res.getAt(pos) orelse unreachable) + 1);
                    q.writeItem(down) catch return ProblemErrors.AllocationFailed;
                }
            }
            if (pos.j > 0) {
                const left = Position{ .i = pos.i, .j = pos.j - 1 };
                if (res.getAt(left) == null and map[left.i][left.j] != '#') {
                    res.setAt(left, (res.getAt(pos) orelse unreachable) + 1);
                    q.writeItem(left) catch return ProblemErrors.AllocationFailed;
                }
            }
            if (pos.j < cols - 1) {
                const right = Position{ .i = pos.i, .j = pos.j + 1 };
                if (res.getAt(right) == null and map[right.i][right.j] != '#') {
                    res.setAt(right, (res.getAt(pos) orelse unreachable) + 1);
                    q.writeItem(right) catch return ProblemErrors.AllocationFailed;
                }
            }
        }

        return res;
    }

    fn deinit(self: *DistanceGrid) void {
        self.allocator.free(self.grid);
    }

    fn set(self: *DistanceGrid, i: usize, j: usize, value: uint) void {
        self.grid[i * self.cols + j] = value;
    }

    fn setAt(self: *DistanceGrid, pos: Position, value: uint) void {
        self.set(pos.i, pos.j, value);
    }

    fn get(self: DistanceGrid, i: usize, j: usize) ?uint {
        return self.grid[i * self.cols + j];
    }

    fn getAt(self: DistanceGrid, pos: Position) ?uint {
        return self.get(pos.i, pos.j);
    }
};

const Position = struct {
    i: usize,
    j: usize,
};

// Tests

test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/21.txt", solve_part_one);
    try std.testing.expectEqual(@as(uint, 3731), res);
}

test "Golden Test Part Two" {
    // TODO Test solve_part_two on your actual problem input here
    // You may use for_lines or for_lines_allocating from tests_lib.zig
}

test "Example Part One" {
    const lines = [_]String{
        "...........",
        ".....###.#.",
        ".###.##..#.",
        "..#.#...#..",
        "....#.#....",
        ".##..S####.",
        ".##..#...#.",
        ".......##..",
        ".##.#.####.",
        ".##..##.##.",
        "...........",
    };
    var grid = try DistanceGrid.init(std.testing.allocator, &lines, 11, 11, 5, 5);
    defer grid.deinit();
    const res = solve(grid, 6);
    try std.testing.expectEqual(@as(uint, 16), res);
}

test "Example Part Two" {
    // TODO Test solve_part_two on the problem example here
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    const res = solve_part_two(lines);
    try std.testing.expectEqual(@as(uint, 42), res);
}
