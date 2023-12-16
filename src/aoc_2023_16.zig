const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u32;
const ProblemErrors = error{AllocationFailed};

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    return gridScan(allocator, lines.items, Beam{ .i = 0, .j = 0, .direction = Direction.Right }) catch unreachable;
}

pub fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    const lastRow = lines.items.len - 1;
    const lastColumn = lines.items[0].len - 1;
    var max: uint = 0;
    const topLeftRight = gridScan(allocator, lines.items, Beam{ .i = 0, .j = 0, .direction = Direction.Right }) catch unreachable;
    const topLeftDown = gridScan(allocator, lines.items, Beam{ .i = 0, .j = 0, .direction = Direction.Down }) catch unreachable;
    const topRightLeft = gridScan(allocator, lines.items, Beam{ .i = 0, .j = lastColumn, .direction = Direction.Left }) catch unreachable;
    const topRightDown = gridScan(allocator, lines.items, Beam{ .i = 0, .j = lastColumn, .direction = Direction.Down }) catch unreachable;
    const botLeftRight = gridScan(allocator, lines.items, Beam{ .i = lastRow, .j = 0, .direction = Direction.Right }) catch unreachable;
    const botLeftUp = gridScan(allocator, lines.items, Beam{ .i = lastRow, .j = 0, .direction = Direction.Up }) catch unreachable;
    const botRightLeft = gridScan(allocator, lines.items, Beam{ .i = lastRow, .j = lastColumn, .direction = Direction.Right }) catch unreachable;
    const botRightUp = gridScan(allocator, lines.items, Beam{ .i = lastRow, .j = lastColumn, .direction = Direction.Up }) catch unreachable;
    max = @max(max, topLeftRight);
    max = @max(max, topLeftDown);
    max = @max(max, topRightLeft);
    max = @max(max, topRightDown);
    max = @max(max, botLeftRight);
    max = @max(max, botLeftUp);
    max = @max(max, botRightLeft);
    max = @max(max, botRightUp);

    for (1..lastColumn) |j| {
        const down = gridScan(allocator, lines.items, Beam{ .i = 0, .j = j, .direction = Direction.Down }) catch unreachable;
        const up = gridScan(allocator, lines.items, Beam{ .i = lastRow, .j = j, .direction = Direction.Up }) catch unreachable;
        max = @max(max, down);
        max = @max(max, up);
    }

    for (1..lastRow) |i| {
        const right = gridScan(allocator, lines.items, Beam{ .i = i, .j = 0, .direction = Direction.Right }) catch unreachable;
        const left = gridScan(allocator, lines.items, Beam{ .i = i, .j = lastColumn, .direction = Direction.Left }) catch unreachable;
        max = @max(max, right);
        max = @max(max, left);
    }

    return max;
}

const Direction = union(enum(u2)) {
    Left = 0,
    Up = 1,
    Right = 2,
    Down = 3,

    inline fn idx(self: Direction) usize {
        return @intFromEnum(self);
    }

    inline fn set(self: Direction, value: anytype, slice: []@TypeOf(value)) void {
        slice[self.idx()] = value;
    }
};
const DirectionalScan = [@typeInfo(Direction).Union.fields.len]bool;

const TileTag = enum {
    Mirror_Slash,
    Mirror_BackSlash,
    Splitter_Horizontal,
    Splitter_Vertical,
    Empty,

    fn fromByte(c: u8) TileTag {
        return switch (c) {
            '/' => .Mirror_Slash,
            '\\' => .Mirror_BackSlash,
            '|' => .Splitter_Vertical,
            '-' => .Splitter_Horizontal,
            else => .Empty,
        };
    }
};

fn gridScan(allocator: std.mem.Allocator, grid: []const String, startBeam: Beam) ProblemErrors!uint {
    var copy = allocator.alloc(DirectionalScan, grid.len * grid[0].len) catch return ProblemErrors.AllocationFailed;
    defer allocator.free(copy);
    for (copy) |*b| {
        for (0..@typeInfo(Direction).Union.fields.len) |di| {
            b.*[di] = false;
        }
    }
    var accessor = GridAccessor(DirectionalScan).make(copy, grid[0].len, grid.len);

    var q = std.ArrayList(Beam).init(allocator);
    defer q.deinit();
    const initialDirections = changeDirection(startBeam.direction, TileTag.fromByte(grid[startBeam.i][startBeam.j]));
    try appendIfNotAlreadyReached(startBeam.i, startBeam.j, initialDirections, accessor, &q);

    while (q.popOrNull()) |beam| {
        switch (beam.direction) {
            .Left => if (beam.j > 0) {
                const next = changeDirection(beam.direction, TileTag.fromByte(grid[beam.i][beam.j - 1]));
                try appendIfNotAlreadyReached(beam.i, beam.j - 1, next, accessor, &q);
            },
            .Right => if (beam.j < accessor.width - 1) {
                const next = changeDirection(beam.direction, TileTag.fromByte(grid[beam.i][beam.j + 1]));
                try appendIfNotAlreadyReached(beam.i, beam.j + 1, next, accessor, &q);
            },
            .Down => if (beam.i < accessor.height - 1) {
                const next = changeDirection(beam.direction, TileTag.fromByte(grid[beam.i + 1][beam.j]));
                try appendIfNotAlreadyReached(beam.i + 1, beam.j, next, accessor, &q);
            },
            .Up => if (beam.i > 0) {
                const next = changeDirection(beam.direction, TileTag.fromByte(grid[beam.i - 1][beam.j]));
                try appendIfNotAlreadyReached(beam.i - 1, beam.j, next, accessor, &q);
            },
        }
    }
    return sum(accessor);
}

fn appendIfNotAlreadyReached(i: usize, j: usize, next: [2]?Direction, accessor: GridAccessor(DirectionalScan), q: *std.ArrayList(Beam)) ProblemErrors!void {
    for (next) |opt| {
        if (opt) |direction| {
            if (!accessor.get(i, j)[direction.idx()]) {
                accessor.get(i, j)[direction.idx()] = true;
                q.append(Beam{ .i = i, .j = j, .direction = direction }) catch return ProblemErrors.AllocationFailed;
            }
        }
    }
}

fn sum(scan: GridAccessor(DirectionalScan)) uint {
    var res: uint = 0;
    for (0..scan.height) |i| {
        for (0..scan.width) |j| {
            var any = false;
            for (scan.get(i, j)) |b| {
                any = any or b;
            }
            if (any) res += 1;
        }
    }
    return res;
}

fn GridAccessor(comptime t: type) type {
    return struct {
        grid: []t,
        width: usize,
        height: usize,
        const Self = @This();

        fn make(grid: []t, width: usize, height: usize) Self {
            return Self{ .grid = grid, .width = width, .height = height };
        }

        inline fn get(self: Self, i: usize, j: usize) *t {
            return &self.grid[i * self.width + j];
        }

        inline fn set(self: *Self, i: usize, j: usize, v: t) void {
            self.grid[i * self.width + j] = v;
        }
    };
}

fn changeDirection(direction: Direction, tile: TileTag) [2]?Direction {
    return switch (direction) {
        .Up => switch (tile) {
            .Mirror_BackSlash => [2]?Direction{ .Left, null },
            .Mirror_Slash => [2]?Direction{ .Right, null },
            .Splitter_Vertical => [2]?Direction{ .Up, null },
            .Splitter_Horizontal => [2]?Direction{ .Left, .Right },
            .Empty => [2]?Direction{ .Up, null },
        },
        .Down => switch (tile) {
            .Mirror_BackSlash => [2]?Direction{ .Right, null },
            .Mirror_Slash => [2]?Direction{ .Left, null },
            .Splitter_Vertical => [2]?Direction{ .Down, null },
            .Splitter_Horizontal => [2]?Direction{ .Left, .Right },
            .Empty => [2]?Direction{ .Down, null },
        },
        .Left => switch (tile) {
            .Mirror_BackSlash => [2]?Direction{ .Up, null },
            .Mirror_Slash => [2]?Direction{ .Down, null },
            .Splitter_Horizontal => [2]?Direction{ .Left, null },
            .Splitter_Vertical => [2]?Direction{ .Up, .Down },
            .Empty => [2]?Direction{ .Left, null },
        },
        .Right => switch (tile) {
            .Mirror_BackSlash => [2]?Direction{ .Down, null },
            .Mirror_Slash => [2]?Direction{ .Up, null },
            .Splitter_Horizontal => [2]?Direction{ .Right, null },
            .Splitter_Vertical => [2]?Direction{ .Up, .Down },
            .Empty => [2]?Direction{ .Right, null },
        },
    };
}

const Beam = struct {
    i: usize,
    j: usize,
    direction: Direction,
};

// Tests

test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/16.txt", solve_part_one);
    try std.testing.expectEqual(@as(uint, 8389), res);
}

test "Golden Test Part Two" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/16.txt", solve_part_two);
    try std.testing.expectEqual(@as(uint, 8564), res);
}

test "Example Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    try lines.append(".|...\\....");
    try lines.append("|.-.\\.....");
    try lines.append(".....|-...");
    try lines.append("........|.");
    try lines.append("..........");
    try lines.append(".........\\");
    try lines.append("..../.\\\\..");
    try lines.append(".-.-/..|..");
    try lines.append(".|....-|.\\");
    try lines.append("..//.|....");
    defer lines.deinit();
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 46), res);
}

test "Custom Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    try lines.append("..\\..");
    try lines.append("..-..");
    defer lines.deinit();
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 8), res);
}

test "Example Part Two" {
    // TODO Test solve_part_two on the problem example here
    var lines = std.ArrayList(String).init(std.testing.allocator);
    try lines.append(".|...\\....");
    try lines.append("|.-.\\.....");
    try lines.append(".....|-...");
    try lines.append("........|.");
    try lines.append("..........");
    try lines.append(".........\\");
    try lines.append("..../.\\\\..");
    try lines.append(".-.-/..|..");
    try lines.append(".|....-|.\\");
    try lines.append("..//.|....");
    defer lines.deinit();
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 51), res);
}

test "Change Direction" {
    const TestCase = struct { Direction, TileTag, [2]?Direction };
    const cases: []const TestCase = &.{
        .{ Direction.Up, TileTag.Mirror_BackSlash, [2]?Direction{ .Left, null } },
        .{ Direction.Up, TileTag.Mirror_Slash, [2]?Direction{ .Right, null } },
        .{ Direction.Down, TileTag.Mirror_BackSlash, [2]?Direction{ .Right, null } },
        .{ Direction.Down, TileTag.Mirror_Slash, [2]?Direction{ .Left, null } },
        .{ Direction.Left, TileTag.Mirror_Slash, [2]?Direction{ .Down, null } },
        .{ Direction.Left, TileTag.Mirror_BackSlash, [2]?Direction{ .Up, null } },
        .{ Direction.Right, TileTag.Mirror_Slash, [2]?Direction{ .Up, null } },
        .{ Direction.Right, TileTag.Mirror_BackSlash, [2]?Direction{ .Down, null } },
    };
    for (cases) |testCase| {
        const direction = testCase[0];
        const tile = testCase[1];
        const result = changeDirection(direction, tile);
        try std.testing.expectEqual(testCase[2], result);
    }

    for (&[2]Direction{ Direction.Left, Direction.Right }) |d| {
        var unchanged = changeDirection(d, TileTag.Splitter_Horizontal);
        try std.testing.expectEqual(unchanged, [2]?Direction{ d, null });
        unchanged = changeDirection(d, TileTag.Empty);
        try std.testing.expectEqual(unchanged, [2]?Direction{ d, null });

        const splitted = changeDirection(d, TileTag.Splitter_Vertical);
        try std.testing.expectEqual(splitted, [2]?Direction{ Direction.Up, Direction.Down });
    }

    for (&[2]Direction{ Direction.Up, Direction.Down }) |d| {
        var unchanged = changeDirection(d, TileTag.Splitter_Vertical);
        try std.testing.expectEqual(unchanged, [2]?Direction{ d, null });
        unchanged = changeDirection(d, TileTag.Empty);
        try std.testing.expectEqual(unchanged, [2]?Direction{ d, null });

        const splitted = changeDirection(d, TileTag.Splitter_Horizontal);
        try std.testing.expectEqual(splitted, [2]?Direction{ Direction.Left, Direction.Right });
    }
}
