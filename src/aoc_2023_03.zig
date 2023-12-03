const std = @import("std");
const lib = @import("tests_lib.zig");
const String = lib.String;

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) i32 {
    const grid = Grid.parse(allocator, lines) catch unreachable;
    defer grid.deinit();
    const parts = scanParts(allocator, grid) catch unreachable;
    defer parts.deinit();

    var res: i32 = 0;
    for (parts.items) |p| {
        res += p;
    }
    return res;
}

fn scanParts(allocator: std.mem.Allocator, grid: Grid) !std.ArrayList(i32) {
    var res = std.ArrayList(i32).init(allocator);
    for (0..grid.height) |row| {
        const partsInRow = try scanPartsInRow(allocator, grid, row);
        defer partsInRow.deinit();
        for (partsInRow.items) |p| {
            try res.append(p);
        }
    }
    return res;
}

fn scanPartsInRow(allocator: std.mem.Allocator, grid: Grid, row: usize) !std.ArrayList(i32) {
    var res = std.ArrayList(i32).init(allocator);
    var digitChunk: ?Grid.Chunk = null;
    for (0..grid.width) |c| {
        switch (grid.at(row, c)) {
            .Digit => |d| {
                _ = d;
                if (digitChunk) |*chunk| {
                    chunk.extend();
                } else {
                    digitChunk = Grid.Chunk{ .row = row, .col_start = c, .col_end = c };
                }
            },
            else => {
                try appendChunkIfPresentAndSymbol(grid, digitChunk, &res);
                digitChunk = null;
            },
        }
    }
    try appendChunkIfPresentAndSymbol(grid, digitChunk, &res);
    return res;
}

fn appendChunkIfPresentAndSymbol(grid: Grid, chunk: ?Grid.Chunk, into: *std.ArrayList(i32)) !void {
    if (chunk) |c| {
        if (grid.anyAroundChunk(isSymbol, c)) {
            try into.append(chunkAsNumber(grid, c));
        }
    }
}

const TileTag = enum {
    Digit,
    Symbol,
    Empty,
};

const Tile = union(TileTag) {
    Digit: i32,
    Symbol: u8,
    Empty: void,

    pub fn parse(c: u8) Tile {
        return switch (c) {
            '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => Tile.digit(std.fmt.charToDigit(c, 10) catch unreachable),
            '.' => Tile.empty,
            else => Tile.symbol(c),
        };
    }
    pub fn digit(d: i32) Tile {
        return Tile{ .Digit = d };
    }
    pub fn symbol(c: u8) Tile {
        return Tile{ .Symbol = c };
    }
    pub const empty: Tile = Tile{ .Empty = {} };
};

const Grid = struct {
    tiles: [][]Tile,
    height: usize,
    width: usize,
    allocator: std.mem.Allocator,

    pub fn parse(allocator: std.mem.Allocator, lines: std.ArrayList(String)) !Grid {
        const h = lines.items.len;
        const w = lines.items[1].len;
        var tiles = try allocator.alloc([]Tile, h);
        for (0..h) |r| {
            tiles[r] = try allocator.alloc(Tile, w);
            for (0..w) |c| {
                tiles[r][c] = Tile.parse(lines.items[r][c]);
            }
        }
        return Grid{ .tiles = tiles, .allocator = allocator, .width = w, .height = h };
    }

    pub fn deinit(grid: Grid) void {
        for (grid.tiles) |row| {
            grid.allocator.free(row);
        }
        grid.allocator.free(grid.tiles);
    }

    pub fn at(grid: Grid, row: usize, column: usize) Tile {
        return grid.tiles[row][column];
    }

    pub fn anyAroundChunk(grid: Grid, comptime Match: *const fn (Tile) bool, chunk: Chunk) bool {
        const startCol = if (chunk.col_start == 0) 0 else chunk.col_start - 1;
        const endCol = if (chunk.col_end == grid.width - 1) grid.width - 1 else chunk.col_end + 1;
        if (chunk.row > 0) {
            const topRow = chunk.row - 1;
            for (startCol..endCol + 1) |c| {
                if (Match(grid.at(topRow, c))) {
                    return true;
                }
            }
        }

        if (chunk.row < grid.height - 1) {
            const botRow = chunk.row + 1;
            for (startCol..endCol + 1) |c| {
                if (Match(grid.at(botRow, c))) {
                    return true;
                }
            }
        }

        if (chunk.col_start > 0 and Match(grid.at(chunk.row, chunk.col_start - 1))) {
            return true;
        }

        if (chunk.col_end < grid.width - 1 and Match(grid.at(chunk.row, chunk.col_end + 1))) {
            return true;
        }
        return false;
    }

    const Chunk = struct {
        row: usize,
        col_start: usize,
        col_end: usize,
        pub fn width(c: Chunk) usize {
            return c.col_end - c.col_start + 1;
        }
        pub fn extend(chunk: *Chunk) void {
            chunk.col_end += 1;
        }
    };
};

fn isSymbol(tile: Tile) bool {
    return switch (tile) {
        .Symbol => true,
        else => false,
    };
}

fn chunkAsNumber(grid: Grid, chunk: Grid.Chunk) i32 {
    var res: i32 = 0;
    for (chunk.col_start..chunk.col_end + 1) |c| {
        switch (grid.at(chunk.row, c)) {
            .Digit => |d| {
                res *= 10;
                res += d;
            },
            else => {},
        }
    }
    return res;
}

test "Golden test Part One" {
    const res = try lib.for_lines_allocating(i32, std.testing.allocator, "problems/03.txt", solve_part_one);
    try std.testing.expectEqual(@as(i32, 544664), res);
}

test "Example Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("467..114..");
    try lines.append("...*......");
    try lines.append("..35..633.");
    try lines.append("......#...");
    try lines.append("617*......");
    try lines.append(".....+.58.");
    try lines.append("..592.....");
    try lines.append("......755.");
    try lines.append("...$.*....");
    try lines.append(".664.598..");

    const expected: i32 = 4361;
    try std.testing.expectEqual(expected, solve_part_one(std.testing.allocator, lines));
}

test "Grid.parse" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("..42..");
    try lines.append("..#..0");
    const grid = try Grid.parse(std.testing.allocator, lines);
    defer grid.deinit();

    try std.testing.expectEqual(@as(usize, 2), grid.height);
    try std.testing.expectEqual(@as(usize, 6), grid.width);
    try std.testing.expectEqual(Tile.empty, grid.at(0, 0));
    try std.testing.expectEqual(Tile{ .Digit = 4 }, grid.at(0, 2));
    try std.testing.expectEqual(Tile{ .Digit = 2 }, grid.at(0, 3));
    try std.testing.expectEqual(Tile{ .Symbol = '#' }, grid.at(1, 2));
    try std.testing.expectEqual(Tile{ .Digit = 0 }, grid.at(1, 5));
}

test "Grid.anyAroundChunk" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("..42..");
    try lines.append("....#.");
    try lines.append("...#..");
    try lines.append("..1...");
    try lines.append("......");
    try lines.append("123.#0");
    const grid = try Grid.parse(std.testing.allocator, lines);
    defer grid.deinit();

    const chunkTop = Grid.Chunk{ .row = 0, .col_start = 2, .col_end = 3 };
    const chunkMid = Grid.Chunk{ .row = 3, .col_start = 2, .col_end = 2 };
    const chunkBotLeft = Grid.Chunk{ .row = 5, .col_start = 0, .col_end = 2 };
    const chunkBotRight = Grid.Chunk{ .row = 5, .col_start = 5, .col_end = 5 };
    try std.testing.expectEqual(true, grid.anyAroundChunk(isSymbol, chunkTop));
    try std.testing.expectEqual(true, grid.anyAroundChunk(isSymbol, chunkMid));
    try std.testing.expectEqual(false, grid.anyAroundChunk(isSymbol, chunkBotLeft));
    try std.testing.expectEqual(true, grid.anyAroundChunk(isSymbol, chunkBotRight));
}

test "chunkAsNumber" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("..42..");
    try lines.append("..#..0");
    try lines.append("......");
    try lines.append("123.05");
    const grid = try Grid.parse(std.testing.allocator, lines);
    defer grid.deinit();

    const chunkTop = Grid.Chunk{ .row = 0, .col_start = 2, .col_end = 3 };
    const chunkBotLeft = Grid.Chunk{ .row = 3, .col_start = 0, .col_end = 2 };
    const chunkBotRight = Grid.Chunk{ .row = 3, .col_start = 4, .col_end = 5 };
    try std.testing.expectEqual(@as(i32, 42), chunkAsNumber(grid, chunkTop));
    try std.testing.expectEqual(@as(i32, 123), chunkAsNumber(grid, chunkBotLeft));
    try std.testing.expectEqual(@as(i32, 5), chunkAsNumber(grid, chunkBotRight));
}
