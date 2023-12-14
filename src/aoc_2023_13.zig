const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u32;
const ProblemErrors = error{AllocationFailed};

fn solve_part_one(lines: std.ArrayList(String)) uint {
    var start: usize = 0;
    var end: usize = 0;
    var res: uint = 0;
    for (lines.items, 0..) |l, li| {
        if (l.len == 0) {
            end = li;
            const grid = lines.items[start..end];
            res += score(grid, null, null).max() orelse unreachable;
            start = end + 1;
        }
    }

    // Last grid
    if (end < lines.items.len) {
        const grid = lines.items[start..lines.items.len];
        res += score(grid, null, null).max() orelse unreachable;
    }
    return res;
}

fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    var start: usize = 0;
    var end: usize = 0;
    var res: uint = 0;
    var gridNb: usize = 1;
    for (lines.items, 0..) |l, li| {
        if (l.len == 0) {
            end = li;
            const grid = lines.items[start..end];
            res += (scoreWithFlip(allocator, grid) catch unreachable) orelse unreachable;
            start = end + 1;
            gridNb += 1;
        }
    }

    // Last grid
    if (end < lines.items.len) {
        const grid = lines.items[start..lines.items.len];
        res += (scoreWithFlip(allocator, grid) catch unreachable) orelse unreachable;
    }
    return res;
}

fn scoreWithFlip(allocator: std.mem.Allocator, grid: []const String) !?uint {
    var copy = try allocator.alloc([]u8, grid.len);
    if (grid[0].len >= 100) unreachable;
    defer {
        for (copy) |row| {
            allocator.free(row);
        }
        allocator.free(copy);
    }
    for (grid, 0..) |row, i| {
        copy[i] = try allocator.alloc(u8, row.len);
        for (row, 0..) |c, j| {
            copy[i][j] = c;
        }
    }
    const usualScore = score(grid, null, null);
    for (0..grid.len) |i| {
        for (0..grid[i].len) |j| {
            flip(copy, i, j);
            const s = score(copy, usualScore.horizontal, usualScore.vertical);
            if (s.horizontal != usualScore.horizontal) {
                if (s.horizontal) |h| return 100 * uint_of_usize(h);
            }
            if (s.vertical != usualScore.vertical) {
                if (s.vertical) |v| return uint_of_usize(v);
            }
            flip(copy, i, j);
        }
    }
    return null;
}

fn flip(grid: [][]u8, i: usize, j: usize) void {
    grid[i][j] = if (grid[i][j] == '#') '.' else '#';
}

fn score(grid: []const String, ignoreRow: ?usize, ignoreCol: ?usize) Score {
    var res = Score{ .horizontal = null, .vertical = null };
    for (0..grid.len) |i| {
        if (i == ignoreRow) continue;
        if (isMirrorRow(i, grid)) {
            res.horizontal = i;
            break;
        }
    }
    for (0..grid[0].len) |j| {
        if (j == ignoreCol) continue;
        if (isMirrorColumn(j, grid)) {
            res.vertical = j;
            break;
        }
    }
    return res;
}

const Score = struct {
    horizontal: ?usize,
    vertical: ?usize,

    inline fn max(self: Score) ?uint {
        if (self.horizontal) |h| {
            return uint_of_usize(h) * 100;
        }
        if (self.vertical) |v| {
            return uint_of_usize(v);
        }
        return null;
    }
};

fn uint_of_usize(u: usize) uint {
    return @as(uint, @intCast(u));
}

// Tests

test "Golden Test Part One" {
    const res = try lib.for_lines(uint, "problems/13.txt", solve_part_one);
    try std.testing.expectEqual(@as(uint, 33047), res);
}

test "Golden Test Part Two" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/13.txt", solve_part_two);
    try std.testing.expectEqual(@as(uint, 28806), res);
}

test "Example Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("#.##..##.");
    try lines.append("..#.##.#.");
    try lines.append("##......#");
    try lines.append("##......#");
    try lines.append("..#.##.#.");
    try lines.append("..##..##.");
    try lines.append("#.#.##.#.");
    try lines.append("");
    try lines.append("#...##..#");
    try lines.append("#....#..#");
    try lines.append("..##..###");
    try lines.append("#####.##.");
    try lines.append("#####.##.");
    try lines.append("..##..###");
    try lines.append("#....#..#");
    const res = solve_part_one(lines);
    try std.testing.expectEqual(@as(uint, 405), res);
}

test "Example Part Two" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("#.##..##.");
    try lines.append("..#.##.#.");
    try lines.append("##......#");
    try lines.append("##......#");
    try lines.append("..#.##.#.");
    try lines.append("..##..##.");
    try lines.append("#.#.##.#.");
    try lines.append("");
    try lines.append("#...##..#");
    try lines.append("#....#..#");
    try lines.append("..##..###");
    try lines.append("#####.##.");
    try lines.append("#####.##.");
    try lines.append("..##..###");
    try lines.append("#....#..#");
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 400), res);
}

test "Vertical to horizontal" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("..#.");
    try lines.append("..#.");
}

fn isMirrorRow(i: usize, grid: []const String) bool {
    if (i == 0) return false;
    var upIndex = i - 1;
    var downIndex = i;
    while (upIndex >= 0 and downIndex < grid.len) : ({
        upIndex -= 1;
        downIndex += 1;
    }) {
        const up = grid[upIndex];
        const down = grid[downIndex];
        for (up, 0..) |c, j| {
            if (c != down[j]) return false;
        }
        if (upIndex == 0) break;
    }
    return true;
}

fn isMirrorColumn(j: usize, grid: []const String) bool {
    const cols = grid[0].len;
    if (j == 0) return false;
    var leftIndex = j - 1;
    var rightIndex = j;
    while (leftIndex >= 0 and rightIndex < cols) : ({
        leftIndex -= 1;
        rightIndex += 1;
    }) {
        for (0..grid.len) |i| {
            if (grid[i][leftIndex] != grid[i][rightIndex]) return false;
        }
        if (leftIndex == 0) break;
    }
    return true;
}

test "isMirrorRow" {
    const lines = [_]String{
        "#...##..#",
        "#....#..#",
        "..##..###",
        "#####.##.",
        "#####.##.",
        "..##..###",
        "#....#..#",
    };
    try expect(isMirrorRow(4, &lines));
    for (0..lines.len) |i| {
        if (i == 4) continue;
        try expect(!isMirrorRow(i, &lines));
    }
}

test "isMirrorColumn" {
    const lines = [_]String{
        "#.##..##.",
        "..#.##.#.",
        "##......#",
        "##......#",
        "..#.##.#.",
        "..##..##.",
        "#.#.##.#.",
    };
    try expect(isMirrorColumn(5, &lines));
    for (0..lines.len) |i| {
        if (i == 5) continue;
        try expect(!isMirrorColumn(i, &lines));
    }
}
