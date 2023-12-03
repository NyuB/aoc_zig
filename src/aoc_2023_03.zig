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
        try scanPartsInRow(grid, row, &res);
    }
    return res;
}

fn scanPartsInRow(grid: Grid, row: usize, into: *std.ArrayList(i32)) !void {
    var digitChunk: ?Grid.Chunk = null;
    for (0..grid.width) |c| {
        switch (grid.at(row, c)) {
            .Digit => |_| {
                if (digitChunk) |*chunk| {
                    chunk.extend();
                } else {
                    digitChunk = Grid.Chunk{ .row = row, .col_start = c, .col_end = c };
                }
            },
            else => {
                try appendChunkIfPresentAndSymbol(grid, digitChunk, into);
                digitChunk = null;
            },
        }
    }
    try appendChunkIfPresentAndSymbol(grid, digitChunk, into);
}

pub fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) i32 {
    var grid = Grid.parse(allocator, lines) catch unreachable;
    defer grid.deinit();
    var gears = scanGears(allocator, grid) catch unreachable;
    defer gears.deinit();
    return sumGears(gears);
}

const ScanType = struct { map: *GearMap, grid: Grid, chunk: Grid.Chunk };
fn scanGears(allocator: std.mem.Allocator, grid: Grid) !GearMap {
    var res = GearMap.init(allocator);
    for (0..grid.height) |row| {
        try scanGearsInRow(grid, row, &res);
    }
    return res;
}

fn scanGearsInRow(grid: Grid, row: usize, map: *GearMap) !void {
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
                if (digitChunk) |chunk| {
                    var acc = ScanType{ .map = map, .grid = grid, .chunk = chunk };
                    _ = grid.forEachTileAroundChunk(*ScanType, scanGearItem, &acc, chunk);
                }
                digitChunk = null;
            },
        }
    }
    if (digitChunk) |chunk| {
        var acc = ScanType{ .map = map, .grid = grid, .chunk = chunk };
        _ = grid.forEachTileAroundChunk(*ScanType, scanGearItem, &acc, chunk);
    }
}

fn scanGearItem(acc: *ScanType, rowCol: RowCol, tile: Tile) *ScanType {
    switch (tile) {
        .Symbol => |s| {
            if (s == '*') {
                const findOpt = acc.map.get(rowCol);
                if (findOpt) |gear| {
                    switch (gear) {
                        .OneChunk => |i| {
                            acc.map.put(rowCol, GearCandidate{ .TwoChunks = i * chunkAsNumber(acc.grid, acc.chunk) }) catch unreachable;
                        },
                        else => {
                            acc.map.put(rowCol, GearCandidate{ .MoreThanTwoChunks = {} }) catch unreachable;
                        },
                    }
                } else {
                    acc.map.put(rowCol, GearCandidate{ .OneChunk = chunkAsNumber(acc.grid, acc.chunk) }) catch unreachable;
                }
            }
        },
        else => {},
    }
    return acc;
}

fn sumGears(map: GearMap) i32 {
    var it = map.valueIterator();
    var res: i32 = 0;
    while (it.next()) |g| {
        switch (g.*) {
            .TwoChunks => |i| {
                res += i;
            },
            else => {},
        }
    }
    return res;
}

fn appendChunkIfPresentAndSymbol(grid: Grid, chunk: ?Grid.Chunk, into: *std.ArrayList(i32)) !void {
    if (chunk) |c| {
        if (atLeastOneSymbolAroundChunk(grid, c)) {
            try into.append(chunkAsNumber(grid, c));
        }
    }
}

const RowCol = struct { row: usize, col: usize };

const GearCandidateTag = enum { OneChunk, TwoChunks, MoreThanTwoChunks };
const GearCandidate = union(GearCandidateTag) { OneChunk: i32, TwoChunks: i32, MoreThanTwoChunks };

const GearMap = std.AutoHashMap(RowCol, GearCandidate);

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

    pub fn forEachTileAroundChunk(grid: Grid, comptime Result: type, comptime Do: *const fn (Result, RowCol, Tile) Result, init: Result, chunk: Chunk) Result {
        const startCol = if (chunk.col_start == 0) 0 else chunk.col_start - 1;
        const endCol = if (chunk.col_end == grid.width - 1) grid.width - 1 else chunk.col_end + 1;
        var res = init;
        if (chunk.row > 0) {
            const topRow = chunk.row - 1;
            for (startCol..endCol + 1) |c| {
                res = Do(res, RowCol{ .row = topRow, .col = c }, grid.at(topRow, c));
            }
        }

        if (chunk.row < grid.height - 1) {
            const botRow = chunk.row + 1;
            for (startCol..endCol + 1) |c| {
                res = Do(res, RowCol{ .row = botRow, .col = c }, grid.at(botRow, c));
            }
        }

        if (chunk.col_start > 0) {
            res = Do(res, RowCol{ .row = chunk.row, .col = chunk.col_start - 1 }, grid.at(chunk.row, chunk.col_start - 1));
        }

        if (chunk.col_end < grid.width - 1) {
            res = Do(res, RowCol{ .row = chunk.row, .col = chunk.col_end + 1 }, grid.at(chunk.row, chunk.col_end + 1));
        }
        return res;
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

fn setTrueIfSymbol(acc: *bool, _: RowCol, t: Tile) *bool {
    if (isSymbol(t)) {
        acc.* = true;
    }
    return acc;
}

fn atLeastOneSymbolAroundChunk(grid: Grid, chunk: Grid.Chunk) bool {
    var res = false;
    _ = grid.forEachTileAroundChunk(*bool, setTrueIfSymbol, &res, chunk);
    return res;
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

test "Golden test Part Two" {
    const res = try lib.for_lines_allocating(i32, std.testing.allocator, "problems/03.txt", solve_part_two);
    try std.testing.expectEqual(@as(i32, 84495585), res);
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

test "Example Part Two" {
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

    const expected: i32 = 467835;
    try std.testing.expectEqual(expected, solve_part_two(std.testing.allocator, lines));
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
    try std.testing.expectEqual(true, atLeastOneSymbolAroundChunk(grid, chunkTop));
    try std.testing.expectEqual(true, atLeastOneSymbolAroundChunk(grid, chunkMid));
    try std.testing.expectEqual(false, atLeastOneSymbolAroundChunk(grid, chunkBotLeft));
    try std.testing.expectEqual(true, atLeastOneSymbolAroundChunk(grid, chunkBotRight));
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
