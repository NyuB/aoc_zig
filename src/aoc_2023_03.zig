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

pub fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) i32 {
    var grid = Grid.parse(allocator, lines) catch unreachable;
    defer grid.deinit();
    var gears = scanGears(allocator, grid) catch unreachable;
    defer gears.deinit();
    return sumGears(gears);
}

const PartScan = struct {
    list: *std.ArrayList(i32),
    grid: Grid,
    fn scanChunk(scan: *PartScan, c: Grid.Chunk) !void {
        if (try atLeastOneSymbolAroundChunk(scan.grid, c)) {
            const n = chunkAsNumber(scan.grid, c);
            try scan.list.append(n);
        }
    }
};

fn scanParts(allocator: std.mem.Allocator, grid: Grid) !std.ArrayList(i32) {
    var res = std.ArrayList(i32).init(allocator);
    var scan = PartScan{ .list = &res, .grid = grid };
    for (0..grid.height) |row| {
        try forEachChunkInRow(grid, row, &scan, PartScan.scanChunk);
    }
    return res;
}

const GearScan = struct {
    map: *GearMap,
    grid: Grid,
    chunk: ?Grid.Chunk,

    fn scanChunk(scan: *GearScan, c: Grid.Chunk) !void {
        scan.chunk = c;
        try scan.grid.forEachTileAroundChunk(*GearScan, GearScan.scanGearItem, scan, c);
    }

    fn scanGearItem(scanState: *GearScan, rowCol: RowCol, tile: Tile) !void {
        if (scanState.chunk) |chunk| {
            switch (tile) {
                .Symbol => |s| {
                    if (s == '*') {
                        const findOpt = scanState.map.get(rowCol);
                        if (findOpt) |gear| {
                            switch (gear) {
                                .OneChunk => |i| {
                                    try scanState.map.put(rowCol, GearCandidate{ .TwoChunks = i * chunkAsNumber(scanState.grid, chunk) });
                                },
                                else => {
                                    try scanState.map.put(rowCol, GearCandidate{ .MoreThanTwoChunks = {} });
                                },
                            }
                        } else {
                            try scanState.map.put(rowCol, GearCandidate{ .OneChunk = chunkAsNumber(scanState.grid, chunk) });
                        }
                    }
                },
                else => {},
            }
        }
    }
};

fn scanGears(allocator: std.mem.Allocator, grid: Grid) !GearMap {
    var res = GearMap.init(allocator);
    var scan = GearScan{ .map = &res, .grid = grid, .chunk = null };
    for (0..grid.height) |row| {
        try forEachChunkInRow(grid, row, &scan, GearScan.scanChunk);
    }
    return res;
}

fn forEachChunkInRow(grid: Grid, row: usize, state: anytype, Do: *const fn (@TypeOf(state), Grid.Chunk) anyerror!void) anyerror!void {
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
                    try Do(state, chunk);
                }
                digitChunk = null;
            },
        }
    }
    if (digitChunk) |chunk| {
        try Do(state, chunk);
    }
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

    pub fn forEachTileAroundChunk(grid: Grid, comptime State: type, comptime Do: *const fn (State, RowCol, Tile) anyerror!void, state: State, chunk: Chunk) anyerror!void {
        const startCol = if (chunk.col_start == 0) 0 else chunk.col_start - 1;
        const endCol = if (chunk.col_end == grid.width - 1) grid.width - 1 else chunk.col_end + 1;
        if (chunk.row > 0) {
            const topRow = chunk.row - 1;
            for (startCol..endCol + 1) |c| {
                try Do(state, RowCol{ .row = topRow, .col = c }, grid.at(topRow, c));
            }
        }

        if (chunk.row < grid.height - 1) {
            const botRow = chunk.row + 1;
            for (startCol..endCol + 1) |c| {
                try Do(state, RowCol{ .row = botRow, .col = c }, grid.at(botRow, c));
            }
        }

        if (chunk.col_start > 0) {
            try Do(state, RowCol{ .row = chunk.row, .col = chunk.col_start - 1 }, grid.at(chunk.row, chunk.col_start - 1));
        }

        if (chunk.col_end < grid.width - 1) {
            try Do(state, RowCol{ .row = chunk.row, .col = chunk.col_end + 1 }, grid.at(chunk.row, chunk.col_end + 1));
        }
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

fn setTrueIfSymbol(flag: *bool, _: RowCol, t: Tile) !void {
    if (isSymbol(t)) {
        flag.* = true;
    }
}

fn atLeastOneSymbolAroundChunk(grid: Grid, chunk: Grid.Chunk) !bool {
    var res = false;
    try grid.forEachTileAroundChunk(*bool, setTrueIfSymbol, &res, chunk);
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
    const actual = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(expected, actual);
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
    try std.testing.expectEqual(true, try atLeastOneSymbolAroundChunk(grid, chunkTop));
    try std.testing.expectEqual(true, try atLeastOneSymbolAroundChunk(grid, chunkMid));
    try std.testing.expectEqual(false, try atLeastOneSymbolAroundChunk(grid, chunkBotLeft));
    try std.testing.expectEqual(true, try atLeastOneSymbolAroundChunk(grid, chunkBotRight));
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
