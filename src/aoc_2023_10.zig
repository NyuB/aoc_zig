const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u32;
const ProblemErrors = error{ AllocationFailed, IllegalState };

fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    var start: ?Position = null;
    for (lines.items, 0..) |row, i| {
        for (row, 0..) |c, j| {
            if (c == 'S') {
                start = Position{ .row = i, .col = j };
            }
        }
    }
    const grid = Grid.make(lines.items) catch unreachable;
    var scan = scanOnLoopContour(allocator, start orelse unreachable, grid) catch unreachable;
    defer scan.deinit();
    return scan.maxDist();
}

/// Returns two values, each corresponding to the count of tiles in or out of the loop ... which is which remains unknown :P
fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) [2]uint {
    var start: ?Position = null;
    for (lines.items, 0..) |row, i| {
        for (row, 0..) |c, j| {
            if (c == 'S') {
                start = Position{ .row = i, .col = j };
            }
        }
    }
    const grid = Grid.make(lines.items) catch unreachable;
    var scan = scanOnLoopContour(allocator, start orelse unreachable, grid) catch unreachable;
    defer scan.deinit();
    scanInOutLoop(allocator, &scan, start orelse unreachable, grid) catch unreachable;
    scan.noUnknown() catch unreachable;
    const in = scan.countIn();
    const out = scan.countOut();
    return [2]uint{ @min(in, out), @max(in, out) };
}

fn scanOnLoopContour(allocator: std.mem.Allocator, start: Position, grid: Grid) ProblemErrors!LoopScan {
    var scan = try LoopScan.init(allocator, grid.map.len, grid.map[0].len);
    scan.set(start, LoopScanStatus{ .On = 0 });
    var q = std.ArrayList(Position).init(allocator);
    defer q.deinit();
    q.append(start) catch return ProblemErrors.AllocationFailed;
    while (q.popOrNull()) |n| {
        const dist = try scan.getLoopDistanceExn(n);
        for (grid.pipeNeighbours(n)) |maybe| {
            if (maybe) |neighbour| {
                if (scan.getLoopDistanceOpt(neighbour)) |neighbourDist| {
                    if (dist + 1 < neighbourDist) {
                        try updateDistanceAndAddToQueue(neighbour, dist + 1, &scan, &q);
                    }
                } else {
                    try updateDistanceAndAddToQueue(neighbour, dist + 1, &scan, &q);
                }
            }
        }
    }

    return scan;
}

fn updateDistanceAndAddToQueue(neighbour: Position, newDist: uint, scan: *LoopScan, queue: *std.ArrayList(Position)) ProblemErrors!void {
    scan.set(neighbour, LoopScanStatus{ .On = newDist });
    queue.insert(0, neighbour) catch return ProblemErrors.AllocationFailed;
}

const Direction = enum(usize) {
    LEFT,
    UP,
    RIGHT,
    DOWN,

    fn idx(self: Direction) usize {
        return @intFromEnum(self);
    }
};

/// Assumes clockwise rotation along the loop starting from `start`, fills in and out tiles along the way
fn scanInOutLoop(allocator: std.mem.Allocator, scan: *LoopScan, start: Position, grid: Grid) ProblemErrors!void {
    var currentDirection = Direction.LEFT;
    var currentPosition: Position = start;
    loop: while (true) {
        const neighbourOptions = neighbours(currentPosition, scan.rowCount(), scan.columnCount());
        const nextDirection = nextNeighbourDirectionInLoop(currentPosition, currentDirection, scan.*, grid);

        switch (nextDirection) {
            .LEFT => {
                if (neighbourOptions[Direction.UP.idx()]) |up| {
                    try fillFrom(allocator, scan, up, LoopScanStatus.In);
                }
                if (neighbourOptions[Direction.DOWN.idx()]) |down| {
                    try fillFrom(allocator, scan, down, LoopScanStatus.Out);
                }
                if (neighbourOptions[Direction.RIGHT.idx()]) |right| {
                    try fillFrom(allocator, scan, right, if (currentDirection == Direction.DOWN) LoopScanStatus.Out else LoopScanStatus.In);
                }
            },
            .RIGHT => {
                if (neighbourOptions[Direction.DOWN.idx()]) |down| {
                    try fillFrom(allocator, scan, down, LoopScanStatus.In);
                }
                if (neighbourOptions[Direction.UP.idx()]) |up| {
                    try fillFrom(allocator, scan, up, LoopScanStatus.Out);
                }
                if (neighbourOptions[Direction.LEFT.idx()]) |right| {
                    try fillFrom(allocator, scan, right, if (currentDirection == Direction.UP) LoopScanStatus.Out else LoopScanStatus.In);
                }
            },
            .UP => {
                if (neighbourOptions[Direction.RIGHT.idx()]) |right| {
                    try fillFrom(allocator, scan, right, LoopScanStatus.In);
                }
                if (neighbourOptions[Direction.LEFT.idx()]) |left| {
                    try fillFrom(allocator, scan, left, LoopScanStatus.Out);
                }
                if (neighbourOptions[Direction.DOWN.idx()]) |right| {
                    try fillFrom(allocator, scan, right, if (currentDirection == Direction.LEFT) LoopScanStatus.Out else LoopScanStatus.In);
                }
            },
            .DOWN => {
                if (neighbourOptions[Direction.LEFT.idx()]) |left| {
                    try fillFrom(allocator, scan, left, LoopScanStatus.In);
                }
                if (neighbourOptions[Direction.RIGHT.idx()]) |right| {
                    try fillFrom(allocator, scan, right, LoopScanStatus.Out);
                }
                if (neighbourOptions[Direction.UP.idx()]) |right| {
                    try fillFrom(allocator, scan, right, if (currentDirection == Direction.RIGHT) LoopScanStatus.Out else LoopScanStatus.In);
                }
            },
        }
        currentDirection = nextDirection;
        currentPosition = neighbourOptions[currentDirection.idx()] orelse unreachable;
        if (currentPosition.row == start.row and currentPosition.col == start.col) break :loop;
    }
}

/// Preserves clockwise rotation
fn nextNeighbourDirectionInLoop(position: Position, direction: Direction, scan: LoopScan, grid: Grid) Direction {
    const neighbourOptions = grid.pipeNeighbours(position);
    switch (direction) {
        .LEFT => {
            if (neighbourOptions[Direction.LEFT.idx()]) |left| {
                if (scan.isOn(left)) return Direction.LEFT;
            }
            if (neighbourOptions[Direction.UP.idx()]) |up| {
                if (scan.isOn(up))
                    return Direction.UP;
            }
            if (neighbourOptions[Direction.DOWN.idx()]) |down| {
                if (scan.isOn(down))
                    return Direction.DOWN;
            }
            unreachable;
        },
        .RIGHT => {
            if (neighbourOptions[Direction.RIGHT.idx()]) |right| {
                if (scan.isOn(right)) return Direction.RIGHT;
            }
            if (neighbourOptions[Direction.DOWN.idx()]) |down| {
                if (scan.isOn(down))
                    return Direction.DOWN;
            }
            if (neighbourOptions[Direction.UP.idx()]) |up| {
                if (scan.isOn(up))
                    return Direction.UP;
            }
            unreachable;
        },
        .UP => {
            if (neighbourOptions[Direction.UP.idx()]) |up| {
                if (scan.isOn(up))
                    return Direction.UP;
            }
            if (neighbourOptions[Direction.RIGHT.idx()]) |right| {
                if (scan.isOn(right)) return Direction.RIGHT;
            }
            if (neighbourOptions[Direction.LEFT.idx()]) |left| {
                if (scan.isOn(left))
                    return Direction.LEFT;
            }
            unreachable;
        },
        .DOWN => {
            if (neighbourOptions[Direction.DOWN.idx()]) |down| {
                if (scan.isOn(down))
                    return Direction.DOWN;
            }
            if (neighbourOptions[Direction.LEFT.idx()]) |left| {
                if (scan.isOn(left))
                    return Direction.LEFT;
            }
            if (neighbourOptions[Direction.RIGHT.idx()]) |right| {
                if (scan.isOn(right)) return Direction.RIGHT;
            }
            unreachable;
        },
    }
}

/// Flood fill unknown statuses with the given value
fn fillFrom(allocator: std.mem.Allocator, scan: *LoopScan, start: Position, value: LoopScanStatus) ProblemErrors!void {
    if (scan.get(start) != LoopScanStatus.Unknown) {
        return;
    }
    scan.set(start, value);
    var q = std.ArrayList(Position).init(allocator);
    q.append(start) catch return ProblemErrors.AllocationFailed;

    defer q.deinit();
    while (q.popOrNull()) |p| {
        for (neighbours(p, scan.rowCount(), scan.columnCount())) |nOpt| {
            if (nOpt) |n| {
                if (scan.get(n) == LoopScanStatus.Unknown) {
                    scan.set(n, value);
                    q.append(n) catch return ProblemErrors.AllocationFailed;
                }
            }
        }
    }
}

fn neighbours(p: Position, rows: usize, cols: usize) [4]?Position {
    var res: [4]?Position = undefined;
    res[Direction.LEFT.idx()] = if (p.col > 0) Position{ .row = p.row, .col = p.col - 1 } else null;
    res[Direction.UP.idx()] = if (p.row > 0) Position{ .row = p.row - 1, .col = p.col } else null;
    res[Direction.RIGHT.idx()] = if (p.col < cols - 1) Position{ .row = p.row, .col = p.col + 1 } else null;
    res[Direction.DOWN.idx()] = if (p.row < rows - 1) Position{ .row = p.row + 1, .col = p.col } else null;
    return res;
}

const Position = struct {
    row: usize,
    col: usize,

    const Queue = std.TailQueue(Position);
};

const LoopScanTag = enum { On, In, Out, Unknown };

const LoopScanStatus = union(LoopScanTag) {
    /// Loop edge, associated with it's distance from the loop start
    On: uint,
    /// Inside the loop
    In: void,
    /// Outside the loop
    Out: void,
    /// Not yet determined
    Unknown: void,
};

const LoopScan = struct {
    scan: [][]LoopScanStatus,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) ProblemErrors!LoopScan {
        var scan = allocator.alloc([]LoopScanStatus, rows) catch return ProblemErrors.AllocationFailed;
        errdefer allocator.free(scan);
        for (0..rows) |i| {
            var row = allocator.alloc(LoopScanStatus, cols) catch return ProblemErrors.AllocationFailed;
            errdefer allocator.free(row);
            for (row) |*item| {
                item.* = LoopScanStatus.Unknown;
            }
            scan[i] = row;
        }
        return LoopScan{ .scan = scan, .allocator = allocator };
    }

    fn deinit(self: *LoopScan) void {
        for (self.scan) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.scan);
    }

    /// Sanity check to ensure the scan was fully performed
    fn noUnknown(self: LoopScan) ProblemErrors!void {
        for (0..self.rowCount()) |i| {
            for (0..self.columnCount()) |j| {
                if (self.get(Position{ .row = i, .col = j }) == LoopScanStatus.Unknown) {
                    return ProblemErrors.IllegalState;
                }
            }
        }
    }

    fn set(self: *LoopScan, position: Position, status: LoopScanStatus) void {
        self.scan[position.row][position.col] = status;
    }

    fn get(self: LoopScan, position: Position) LoopScanStatus {
        return self.scan[position.row][position.col];
    }

    fn rowCount(self: LoopScan) usize {
        return self.scan.len;
    }

    fn columnCount(self: LoopScan) usize {
        return self.scan[0].len;
    }

    fn isOn(self: LoopScan, position: Position) bool {
        return switch (self.scan[position.row][position.col]) {
            .On => true,
            else => false,
        };
    }

    fn getLoopDistanceExn(self: LoopScan, position: Position) ProblemErrors!uint {
        return switch (self.scan[position.row][position.col]) {
            .On => |d| d,
            else => ProblemErrors.IllegalState,
        };
    }

    fn maxDist(self: LoopScan) uint {
        var res: uint = 0;
        for (self.scan) |row| {
            for (row) |s| {
                switch (s) {
                    .On => |d| res = @max(res, d),
                    else => {},
                }
            }
        }
        return res;
    }

    fn countIn(self: LoopScan) uint {
        var res: uint = 0;
        for (self.scan) |row| {
            for (row) |s| {
                switch (s) {
                    .In => {
                        res += 1;
                    },
                    else => {},
                }
            }
        }
        return res;
    }

    fn countOut(self: LoopScan) uint {
        var res: uint = 0;
        for (self.scan) |row| {
            for (row) |s| {
                switch (s) {
                    .Out => {
                        res += 1;
                    },
                    else => {},
                }
            }
        }
        return res;
    }

    fn getLoopDistanceOpt(self: LoopScan, position: Position) ?uint {
        return switch (self.scan[position.row][position.col]) {
            .On => |d| d,
            else => null,
        };
    }
};

const Grid = struct {
    map: [][]const u8,

    pub fn pipeNeighbours(self: Grid, center: Position) [4]?Position {
        var res: [4]?Position = undefined;
        res[Direction.LEFT.idx()] = self.left(center);
        res[Direction.RIGHT.idx()] = self.right(center);
        res[Direction.UP.idx()] = self.up(center);
        res[Direction.DOWN.idx()] = self.down(center);
        return res;
    }

    pub fn make(map: [][]const u8) ProblemErrors!Grid {
        var cols: ?usize = null;
        for (map) |r| {
            if (cols) |c| {
                if (r.len != c) return ProblemErrors.IllegalState;
            } else {
                cols = r.len;
            }
        }
        return Grid{ .map = map };
    }

    fn left(self: Grid, center: Position) ?Position {
        if (center.col > 0) {
            const centerValue = self.at(center);
            const candidate = Position{ .row = center.row, .col = center.col - 1 };
            const candidateValue = self.at(candidate);
            if ((candidateValue == 'L' or candidateValue == '-' or candidateValue == 'F' or candidateValue == 'S') and
                (centerValue == '-' or centerValue == '7' or centerValue == 'J' or centerValue == 'S'))
            {
                return candidate;
            }
        }
        return null;
    }

    fn right(self: Grid, center: Position) ?Position {
        if (center.col < self.map[0].len - 1) {
            const centerValue = self.at(center);
            const candidate = Position{ .row = center.row, .col = center.col + 1 };
            const candidateValue = self.at(candidate);
            if ((centerValue == 'L' or centerValue == '-' or centerValue == 'F' or centerValue == 'S') and
                (candidateValue == '-' or candidateValue == '7' or candidateValue == 'J' or candidateValue == 'S'))
            {
                return candidate;
            }
        }
        return null;
    }

    fn up(self: Grid, center: Position) ?Position {
        if (center.row > 0) {
            const centerValue = self.at(center);
            const candidate = Position{ .row = center.row - 1, .col = center.col };
            const candidateValue = self.at(candidate);
            if ((candidateValue == '7' or candidateValue == '|' or candidateValue == 'F' or candidateValue == 'S') and
                (centerValue == '|' or centerValue == 'L' or centerValue == 'J' or centerValue == 'S'))
            {
                return candidate;
            }
        }
        return null;
    }

    fn down(self: Grid, center: Position) ?Position {
        if (center.row < self.map.len - 1) {
            const centerValue = self.at(center);
            const candidate = Position{ .row = center.row + 1, .col = center.col };
            const candidateValue = self.at(candidate);
            if ((centerValue == '7' or centerValue == '|' or centerValue == 'F' or centerValue == 'S') and
                (candidateValue == '|' or candidateValue == 'L' or candidateValue == 'J' or candidateValue == 'S'))
            {
                return candidate;
            }
        }
        return null;
    }

    inline fn get(self: Grid, i: usize, j: usize) u8 {
        return self.map[i][j];
    }

    inline fn at(self: Grid, p: Position) u8 {
        return self.get(p.row, p.col);
    }
};

// Tests

test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/10.txt", solve_part_one);
    try std.testing.expectEqual(@as(uint, 6831), res);
}

test "Golden Test Part Two" {
    const res = try lib.for_lines_allocating([2]uint, std.testing.allocator, "problems/10.txt", solve_part_two);
    try std.testing.expectEqual([2]uint{ 305, 5633 }, res);
}

test "Example Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("7-F7-");
    try lines.append(".FJ|7");
    try lines.append("SJLL7");
    try lines.append("|F--J");
    try lines.append("LJ.LJ");
    const grid = try Grid.make(lines.items);
    var res = try scanOnLoopContour(std.testing.allocator, Position{ .row = 2, .col = 0 }, grid);
    defer res.deinit();
    try std.testing.expectEqual(@as(uint, 8), res.maxDist());
}

test "Example Part Two Larger with junks" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("FF7FSF7F7F7F7F7F---7");
    try lines.append("L|LJ||||||||||||F--J");
    try lines.append("FL-7LJLJ||||||LJL-77");
    try lines.append("F--JF--7||LJLJ7F7FJ-");
    try lines.append("L---JF-JLJ.||-FJLJJ7");
    try lines.append("|F|F-JF---7F7-L7L|7|");
    try lines.append("|FFJF7L7F-JF7|JL---7");
    try lines.append("7-L-JL7||F7|L7F-7F7|");
    try lines.append("L.L7LFJ|||||FJL7||LJ");
    try lines.append("L7JLJL-JLJLJL--JLJ.L");
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual([2]uint{ 10, 30 }, res);
}

test "Example Part Two Larger" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append(".F----7F7F7F7F-7....");
    try lines.append(".|F--7||||||||FJ....");
    try lines.append(".||.FJ||||||||L7....");
    try lines.append("FJL7L7LJLJ||LJ.L-7..");
    try lines.append("L--J.L7...LJS7F-7L7.");
    try lines.append("....F-J..F7FJ|L7L7L7");
    try lines.append("....L7.F7||L7|.L7L7|");
    try lines.append(".....|FJLJ|FJ|F7|.LJ");
    try lines.append("....FJL-7.||.||||...");
    try lines.append("....L---J.LJ.LJLJ...");
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual([2]uint{ 8, 52 }, res);
}

test "Example Part Two Simple" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("...........");
    try lines.append(".S-------7.");
    try lines.append(".|F-----7|.");
    try lines.append(".||.....||.");
    try lines.append(".||.....||.");
    try lines.append(".|L-7.F-J|.");
    try lines.append(".|..|.|..|.");
    try lines.append(".L--J.L--J.");
    try lines.append("...........");
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual([2]uint{ 4, 49 }, res);
}

test "Example Part Two Simple Narrow" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("..........");
    try lines.append(".S------7.");
    try lines.append(".|F----7|.");
    try lines.append(".||....||.");
    try lines.append(".||....||.");
    try lines.append(".|L-7F-J|.");
    try lines.append(".|..||..|.");
    try lines.append(".L--JL--J.");
    try lines.append("..........");
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual([2]uint{ 4, 42 }, res);
}

test "Simple Square start top left" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("S---7");
    try lines.append("|...|");
    try lines.append("L---J");
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual([2]uint{ 0, 3 }, res);
}

test "Simple Square start top right" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("F---S");
    try lines.append("|...|");
    try lines.append("L---J");
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual([2]uint{ 0, 3 }, res);
}

test "Simple Square start bot right" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("F---7");
    try lines.append("|...|");
    try lines.append("L---S");
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual([2]uint{ 0, 3 }, res);
}

test "Simple Square start bot left" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("F---7");
    try lines.append("|...|");
    try lines.append("S---J");
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual([2]uint{ 0, 3 }, res);
}
