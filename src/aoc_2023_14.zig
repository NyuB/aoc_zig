const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u32;
const ProblemErrors = error{AllocationFailed};

const ROCK = 'O';
const STOP = '#';
const EMPTY = '.';

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    var copy = MutableGrid.mutableCopy(allocator, lines.items) catch unreachable;
    defer copy.deinit();
    shiftNorth(copy.grid);
    return weights(copy.grid);
}

pub fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    var copy = MutableGrid.mutableCopy(allocator, lines.items) catch unreachable;
    defer copy.deinit();
    performShuffles(allocator, 1000000000, copy.grid) catch unreachable;
    return weights(copy.grid);
}

fn performShuffles(allocator: std.mem.Allocator, n: uint, grid: [][]u8) ProblemErrors!void {
    var cycleStartDetector = U64Map.init(allocator);
    defer cycleStartDetector.deinit();

    // Move rocks until reaching an already reached state
    var h = hash(grid);
    var iterations: uint = 0;
    while (!cycleStartDetector.contains(h) and iterations < n) {
        cycleStartDetector.put(h, iterations) catch return ProblemErrors.AllocationFailed;
        shuffle(grid);
        h = hash(grid);
        iterations += 1;
    }

    if (iterations < n) {
        // Number of shuffles before going back to the current state
        const cycleLen = iterations - (cycleStartDetector.get(h) orelse unreachable);

        // Number of shuffles yet to perform
        const shufflesYetToPerform: uint = (n - iterations);
        // Minimal number of shuffles to find the same result as actually running n cycles
        const effectiveShuffles: uint = shufflesYetToPerform % cycleLen;
        for (0..effectiveShuffles) |_| {
            shuffle(grid);
        }
    }
}

const U64Map = std.AutoHashMap(u64, u32);

fn hash(grid: [][]u8) u64 {
    var hasher = std.hash.Fnv1a_64.init();
    for (grid) |row| {
        hasher.update(row);
    }
    return hasher.final();
}

fn weights(grid: []const String) uint {
    var res: uint = 0;
    for (grid, 0..) |row, i| {
        for (row) |c| {
            if (c == ROCK) {
                res += lib.uint_of_usize(uint, grid.len - i);
            }
        }
    }
    return res;
}

fn shuffle(grid: [][]u8) void {
    shiftNorth(grid);
    shiftWest(grid);
    shiftSouth(grid);
    shiftEast(grid);
}

fn shiftNorth(grid: [][]u8) void {
    for (grid, 0..) |row, i| {
        for (row, 0..) |c, j| {
            if (c == ROCK) {
                shiftRockNorth(i, j, grid);
            }
        }
    }
}

fn shiftWest(grid: [][]u8) void {
    for (grid, 0..) |row, i| {
        for (row, 0..) |c, j| {
            if (c == ROCK) {
                shiftRockWest(i, j, grid);
            }
        }
    }
}

fn shiftSouth(grid: [][]u8) void {
    for (0..grid.len) |i| {
        const rowIndex = grid.len - 1 - i;
        for (grid[rowIndex], 0..) |c, j| {
            if (c == ROCK) {
                shiftRockSouth(rowIndex, j, grid);
            }
        }
    }
}

fn shiftEast(grid: [][]u8) void {
    for (grid, 0..) |row, i| {
        for (0..row.len) |j| {
            const colIndex = row.len - 1 - j;
            if (row[colIndex] == ROCK) {
                shiftRockEast(i, colIndex, grid);
            }
        }
    }
}

fn shiftRockNorth(i: usize, j: usize, grid: [][]u8) void {
    grid[i][j] = EMPTY;
    var end = i;
    while (end > 0) {
        end -= 1;
        if (grid[end][j] == STOP or grid[end][j] == ROCK) {
            grid[end + 1][j] = ROCK;
            return;
        }
    }
    grid[0][j] = ROCK;
}

fn shiftRockWest(i: usize, j: usize, grid: [][]u8) void {
    grid[i][j] = EMPTY;
    var end = j;
    while (end > 0) {
        end -= 1;
        if (grid[i][end] == STOP or grid[i][end] == ROCK) {
            grid[i][end + 1] = ROCK;
            return;
        }
    }
    grid[i][0] = ROCK;
}

fn shiftRockSouth(i: usize, j: usize, grid: [][]u8) void {
    grid[i][j] = EMPTY;
    var end = i;
    while (end < grid.len) {
        end += 1;
        if (end == grid.len or grid[end][j] == STOP or grid[end][j] == ROCK) {
            grid[end - 1][j] = ROCK;
            return;
        }
    }
    unreachable;
}

fn shiftRockEast(i: usize, j: usize, grid: [][]u8) void {
    grid[i][j] = EMPTY;
    var end = j;
    while (end < grid[0].len) {
        end += 1;
        if (end == grid[0].len or grid[i][end] == STOP or grid[i][end] == ROCK) {
            grid[i][end - 1] = ROCK;
            return;
        }
    }
    unreachable;
}

const MutableGrid = struct {
    allocator: std.mem.Allocator,
    grid: [][]u8,

    fn mutableCopy(allocator: std.mem.Allocator, grid: []const String) ProblemErrors!MutableGrid {
        var gridCopy = allocator.alloc([]u8, grid.len) catch return ProblemErrors.AllocationFailed;
        for (grid, 0..) |row, i| {
            var copy = allocator.dupe(u8, row) catch return ProblemErrors.AllocationFailed;
            gridCopy[i] = copy;
        }
        return MutableGrid{ .allocator = allocator, .grid = gridCopy };
    }

    fn deinit(self: *MutableGrid) void {
        for (self.grid) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.grid);
    }
};

// Tests

test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/14.txt", solve_part_one);
    try std.testing.expectEqual(@as(uint, 109596), res);
}

test "Golden Test Part Two" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/14.txt", solve_part_two);
    try std.testing.expectEqual(@as(uint, 96105), res);
}

test "Example Part Two" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("O....#....");
    try lines.append("O.OO#....#");
    try lines.append(".....##...");
    try lines.append("OO.#O....O");
    try lines.append(".O.....O#.");
    try lines.append("O.#..O.#.#");
    try lines.append("..O..#O..O");
    try lines.append(".......O..");
    try lines.append("#....###..");
    try lines.append("#OO..#....");
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 64), res);
}

test "Example Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("O....#....");
    try lines.append("O.OO#....#");
    try lines.append(".....##...");
    try lines.append("OO.#O....O");
    try lines.append(".O.....O#.");
    try lines.append("O.#..O.#.#");
    try lines.append("..O..#O..O");
    try lines.append(".......O..");
    try lines.append("#....###..");
    try lines.append("#OO..#....");
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 136), res);
}

test "shiftNorth" {
    const grid = [_]String{
        "O....#....",
        "O.OO#....#",
        ".....##...",
        "OO.#O....O",
        ".O.....O#.",
        "O.#..O.#.#",
        "..O..#O..O",
        ".......O..",
        "#....###..",
        "#OO..#....",
    };
    const expected = [_]String{
        "OOOO.#.O..",
        "OO..#....#",
        "OO..O##..O",
        "O..#.OO...",
        "........#.",
        "..#....#.#",
        "..O..#.O.O",
        "..O.......",
        "#....###..",
        "#....#....",
    };
    var copy = try MutableGrid.mutableCopy(std.testing.allocator, &grid);
    defer copy.deinit();
    shiftNorth(copy.grid);
    for (expected, 0..) |row, i| {
        try std.testing.expectEqualStrings(row, copy.grid[i]);
    }
}

test "shuffle" {
    const grid = [_]String{
        "O....#....",
        "O.OO#....#",
        ".....##...",
        "OO.#O....O",
        ".O.....O#.",
        "O.#..O.#.#",
        "..O..#O..O",
        ".......O..",
        "#....###..",
        "#OO..#....",
    };
    const expectedFirstShuffle = [_]String{
        ".....#....",
        "....#...O#",
        "...OO##...",
        ".OO#......",
        ".....OOO#.",
        ".O#...O#.#",
        "....O#....",
        "......OOOO",
        "#...O###..",
        "#..OO#....",
    };
    const expectedSecondShuffle = [_]String{
        ".....#....",
        "....#...O#",
        ".....##...",
        "..O#......",
        ".....OOO#.",
        ".O#...O#.#",
        "....O#...O",
        ".......OOO",
        "#..OO###..",
        "#.OOO#...O",
    };
    const expectedThirdShuffle = [_]String{
        ".....#....",
        "....#...O#",
        ".....##...",
        "..O#......",
        ".....OOO#.",
        ".O#...O#.#",
        "....O#...O",
        ".......OOO",
        "#...O###.O",
        "#.OOO#...O",
    };
    var copy = try MutableGrid.mutableCopy(std.testing.allocator, &grid);
    defer copy.deinit();

    shuffle(copy.grid);
    for (expectedFirstShuffle, 0..) |row, i| {
        try std.testing.expectEqualStrings(row, copy.grid[i]);
    }
    shuffle(copy.grid);
    for (expectedSecondShuffle, 0..) |row, i| {
        try std.testing.expectEqualStrings(row, copy.grid[i]);
    }
    shuffle(copy.grid);
    for (expectedThirdShuffle, 0..) |row, i| {
        try std.testing.expectEqualStrings(row, copy.grid[i]);
    }
}
