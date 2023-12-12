const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u64;
const ProblemErrors = error{ AllocationFailed, NoPathFound };

const SIMPLE_GALAXY_EXPANSION = 1;
const HUGE_GALAXY_EXPANSION = 999999;

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    return solve(allocator, lines, SIMPLE_GALAXY_EXPANSION);
}

pub fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    return solve(allocator, lines, HUGE_GALAXY_EXPANSION);
}

pub fn solve(allocator: std.mem.Allocator, lines: std.ArrayList(String), galaxyExpansion: uint) uint {
    var space = Space.parse(allocator, lines.items, galaxyExpansion) catch unreachable;
    defer space.deinit();
    var galaxies = std.ArrayList(Position).init(allocator);
    defer galaxies.deinit();

    for (0..space.rows) |i| {
        for (0..space.columns) |j| {
            if (lines.items[i][j] == '#') {
                galaxies.append(Position.make(i, j)) catch unreachable;
            }
        }
    }

    var res: uint = 0;
    for (0..galaxies.items.len) |a| {
        for (a + 1..galaxies.items.len) |b| {
            const ga = galaxies.items[a];
            const gb = galaxies.items[b];
            res += space.distance(ga, gb) catch unreachable;
        }
    }
    return res;
}

const Space = struct {
    grid: [][4]?Edge,
    allocator: std.mem.Allocator,
    rows: usize,
    columns: usize,

    fn distance(self: Space, origin: Position, destination: Position) ProblemErrors!uint {
        var current = origin;
        var res: uint = 0;
        while (!current.eq(destination)) {
            const edgeOpt =
                if (current.i < destination.i)
                self.getEdge(current.i, current.j, Direction.DOWN)
            else if (current.i > destination.i)
                self.getEdge(current.i, current.j, Direction.UP)
            else if (current.j < destination.j)
                self.getEdge(current.i, current.j, Direction.RIGHT)
            else
                self.getEdge(current.i, current.j, Direction.LEFT);
            const edge = edgeOpt orelse return ProblemErrors.NoPathFound;
            res += edge.distance;
            current.i = edge.i;
            current.j = edge.j;
        }
        return res;
    }

    fn parse(allocator: std.mem.Allocator, lines: []const String, galaxyExpansion: uint) ProblemErrors!Space {
        const height = lines.len;
        const width = lines[0].len;
        var grid = allocator.alloc([4]?Edge, height * width) catch return ProblemErrors.AllocationFailed;
        var res = Space{ .grid = grid, .allocator = allocator, .rows = height, .columns = width };
        for (0..height) |i| {
            for (0..width) |j| {
                grid[i * width + j] = [4]?Edge{ null, null, null, null };
                if (i > 0) {
                    res.setEdge(i, j, Direction.UP, Edge.makeOne(i - 1, j));
                    res.setEdge(i - 1, j, Direction.DOWN, Edge.makeOne(i, j));
                }
                if (j > 0) {
                    res.setEdge(i, j, Direction.LEFT, Edge.makeOne(i, j - 1));
                    res.setEdge(i, j - 1, Direction.RIGHT, Edge.makeOne(i, j));
                }
            }
        }
        res.expandEmptyRows(lines, galaxyExpansion);
        res.expandEmptyColumns(lines, galaxyExpansion);
        return res;
    }

    fn expandEmptyRows(self: *Space, lines: []const String, galaxyExpansion: uint) void {
        if (self.rows <= 1) return;
        for (1..self.rows - 1) |i| {
            var empty = true;
            for (0..self.columns) |j| {
                if (lines[i][j] != '.') empty = false;
            }
            if (empty) {
                for (0..self.columns) |j| {
                    if (self.getEdge(i, j, Direction.UP)) |up| {
                        if (self.getEdge(i, j, Direction.DOWN)) |down| {
                            const newDistance = up.distance + down.distance + galaxyExpansion;
                            self.setEdge(up.i, up.j, Direction.DOWN, Edge.make(down.i, down.j, newDistance));
                            self.setEdge(down.i, down.j, Direction.UP, Edge.make(up.i, up.j, newDistance));
                        }
                    }
                }
            }
        }
    }

    fn expandEmptyColumns(self: *Space, lines: []const String, galaxyExpansion: uint) void {
        if (self.columns <= 1) return;
        for (1..self.columns - 1) |j| {
            var empty = true;
            for (0..self.rows) |i| {
                if (lines[i][j] != '.') empty = false;
            }
            if (empty) {
                for (0..self.rows) |i| {
                    if (self.getEdge(i, j, Direction.LEFT)) |left| {
                        if (self.getEdge(i, j, Direction.RIGHT)) |right| {
                            const newDistance = right.distance + left.distance + galaxyExpansion;
                            self.setEdge(left.i, left.j, Direction.RIGHT, Edge.make(right.i, right.j, newDistance));
                            self.setEdge(right.i, right.j, Direction.LEFT, Edge.make(left.i, left.j, newDistance));
                        }
                    }
                }
            }
        }
    }

    fn deinit(self: *Space) void {
        self.allocator.free(self.grid);
    }

    fn getEdge(self: Space, i: usize, j: usize, direction: Direction) ?Edge {
        return self.grid[i * self.columns + j][direction.idx()];
    }

    fn setEdge(self: *Space, i: usize, j: usize, direction: Direction, edge: Edge) void {
        self.grid[i * self.columns + j][direction.idx()] = edge;
    }

    fn getEdges(self: Space, i: usize, j: usize) [4]?Edge {
        return self.grid[i * self.columns + j];
    }
};

const Direction = enum(u2) {
    LEFT,
    UP,
    RIGHT,
    DOWN,

    inline fn idx(self: Direction) usize {
        return @intFromEnum(self);
    }

    inline fn set(self: Direction, value: anytype, slice: []@TypeOf(value)) void {
        slice[self.idx()] = value;
    }
};

const Edge = struct {
    i: usize,
    j: usize,
    distance: uint,

    fn make(i: usize, j: usize, d: uint) Edge {
        return Edge{ .i = i, .j = j, .distance = d };
    }

    fn makeOne(i: usize, j: usize) Edge {
        return make(i, j, 1);
    }
};

const Position = struct {
    i: usize,
    j: usize,

    fn make(i: usize, j: usize) Position {
        return Position{ .i = i, .j = j };
    }

    fn eq(a: Position, b: Position) bool {
        return a.i == b.i and a.j == b.j;
    }
};

// Tests

test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/11.txt", solve_part_one);
    try std.testing.expectEqual(@as(uint, 9563821), res);
}

test "Golden Test Part Two" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/11.txt", solve_part_two);
    try std.testing.expectEqual(@as(uint, 827009909817), res);
}

test "Example Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("...#......");
    try lines.append(".......#..");
    try lines.append("#.........");
    try lines.append("..........");
    try lines.append("......#...");
    try lines.append(".#........");
    try lines.append(".........#");
    try lines.append("..........");
    try lines.append(".......#..");
    try lines.append("#...#.....");
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 374), res);
}

test "Example Part Two" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("...#......");
    try lines.append(".......#..");
    try lines.append("#.........");
    try lines.append("..........");
    try lines.append("......#...");
    try lines.append(".#........");
    try lines.append(".........#");
    try lines.append("..........");
    try lines.append(".......#..");
    try lines.append("#...#.....");
    const res10 = solve(std.testing.allocator, lines, 9);
    const res100 = solve(std.testing.allocator, lines, 99);
    try std.testing.expectEqual(@as(uint, 1030), res10);
    try std.testing.expectEqual(@as(uint, 8410), res100);
}

test "Example distance 5 -> 9" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("...#......");
    try lines.append(".......#..");
    try lines.append("#.........");
    try lines.append("..........");
    try lines.append("......#...");
    try lines.append(".#........");
    try lines.append(".........#");
    try lines.append("..........");
    try lines.append(".......#..");
    try lines.append("#...#.....");
    var space = try Space.parse(std.testing.allocator, lines.items, SIMPLE_GALAXY_EXPANSION);
    defer space.deinit();
    const dist = try space.distance(Position.make(5, 1), Position.make(9, 4));
    try std.testing.expectEqual(@as(uint, 9), dist);
}

test "Parse Example" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("...#......");
    try lines.append(".......#..");
    try lines.append("#.........");
    try lines.append("..........");
    try lines.append("......#...");
    try lines.append(".#........");
    try lines.append(".........#");
    try lines.append("..........");
    try lines.append(".......#..");
    try lines.append("#...#.....");
    var space = try Space.parse(std.testing.allocator, lines.items, SIMPLE_GALAXY_EXPANSION);
    defer space.deinit();

    const verticalEdge = space.getEdge(2, 0, Direction.DOWN);
    try std.testing.expectEqual(@as(?Edge, Edge.make(4, 0, 3)), verticalEdge);
    const verticalEdgeReversed = space.getEdge(4, 0, Direction.UP);
    try std.testing.expectEqual(@as(?Edge, Edge.make(2, 0, 3)), verticalEdgeReversed);

    const horizontalEdge = space.getEdge(0, 1, Direction.RIGHT);
    try std.testing.expectEqual(@as(?Edge, Edge.make(0, 3, 3)), horizontalEdge);
    const horizontalEdgeReversed = space.getEdge(0, 3, Direction.LEFT);
    try std.testing.expectEqual(@as(?Edge, Edge.make(0, 1, 3)), horizontalEdgeReversed);
}

test "Adjacent empty rows" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("#");
    try lines.append(".");
    try lines.append(".");
    try lines.append("#");
    var space = try Space.parse(std.testing.allocator, lines.items, SIMPLE_GALAXY_EXPANSION);
    defer space.deinit();

    const downEdge = space.getEdge(0, 0, Direction.DOWN);
    try std.testing.expectEqual(@as(?Edge, Edge.make(3, 0, 5)), downEdge);
    const upEdge = space.getEdge(3, 0, Direction.UP);
    try std.testing.expectEqual(@as(?Edge, Edge.make(0, 0, 5)), upEdge);
}

test "Adjacent empty columns" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("#...#");
    var space = try Space.parse(std.testing.allocator, lines.items, SIMPLE_GALAXY_EXPANSION);
    defer space.deinit();

    const downEdge = space.getEdge(0, 0, Direction.RIGHT);
    try std.testing.expectEqual(@as(?Edge, Edge.make(0, 4, 7)), downEdge);
    const upEdge = space.getEdge(0, 4, Direction.LEFT);
    try std.testing.expectEqual(@as(?Edge, Edge.make(0, 0, 7)), upEdge);
}
