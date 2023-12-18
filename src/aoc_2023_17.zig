const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u32;
const ProblemErrors = error{ AllocationFailed, IllegalInput };

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    var grid = Grid.parse(allocator, lines.items) catch unreachable;
    defer grid.deinit();
    const res = solve(allocator, grid.items, 0, 3) catch unreachable;
    return res;
}

pub fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    var grid = Grid.parse(allocator, lines.items) catch unreachable;
    defer grid.deinit();
    const res = solve(allocator, grid.items, 4, 10) catch unreachable;
    return res;
}

const Grid = struct {
    items: [][]const uint,
    arena: std.heap.ArenaAllocator,

    /// Caller must call **`Grid.deinit`** on the result
    fn parse(allocator: std.mem.Allocator, lines: []const []const u8) ProblemErrors!Grid {
        const rows = lines.len;
        const cols = if (rows == 0) 0 else lines[0].len;
        var arena = std.heap.ArenaAllocator.init(allocator);
        var arenaAllocator = arena.allocator();

        var res = arenaAllocator.alloc([]uint, rows) catch return ProblemErrors.AllocationFailed;
        for (0..rows) |i| {
            res[i] = arenaAllocator.alloc(uint, cols) catch return ProblemErrors.AllocationFailed;
            for (0..cols) |j| {
                res[i][j] = std.fmt.parseInt(uint, lines[i][j .. j + 1], 10) catch return ProblemErrors.IllegalInput;
            }
        }
        return Grid{ .items = res, .arena = arena };
    }

    fn deinit(self: *Grid) void {
        self.arena.deinit();
    }
};

fn solve(allocator: std.mem.Allocator, grid: []const []const uint, minRepeat: u4, maxRepeat: u4) ProblemErrors!uint {
    const rows = grid.len;
    const cols = if (rows == 0) return ProblemErrors.IllegalInput else grid[0].len;
    const startDown = Node{ .currentDirection = Direction.Down, .directionRepeat = 1, .pos = Position.make(1, 0), .dist = grid[1][0], .minRepeat = minRepeat, .maxRepeat = maxRepeat };
    const startRight = Node{ .currentDirection = Direction.Right, .directionRepeat = 1, .pos = Position.make(0, 1), .dist = grid[0][1], .minRepeat = minRepeat, .maxRepeat = maxRepeat };
    var q = Node.BinaryHeap.init(allocator, Position.make(rows - 1, cols - 1));
    q.add(startDown) catch return ProblemErrors.AllocationFailed;
    q.add(startRight) catch return ProblemErrors.AllocationFailed;
    defer q.deinit();
    var check = try NodeVisitCheck.init(allocator, rows, cols);
    defer check.deinit();

    while (q.removeOrNull()) |n| {
        if (n.directionRepeat >= minRepeat and n.pos.i == rows - 1 and n.pos.j == cols - 1) return n.dist;
        for (n.neighbours(grid)) |opt| {
            if (opt) |next| {
                if (check.get(next)) |already| {
                    if (already > next.dist) {
                        q.add(next) catch return ProblemErrors.AllocationFailed;
                        check.set(next, next.dist);
                    } else {}
                } else {
                    q.add(next) catch return ProblemErrors.AllocationFailed;
                    check.set(next, next.dist);
                }
            }
        }
    }
    return ProblemErrors.IllegalInput;
}

const NodeVisitCheck = struct {
    check: []?uint,
    allocator: std.mem.Allocator,
    rows: usize,
    cols: usize,

    const RepeatCardinality: usize = 11;

    fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) ProblemErrors!NodeVisitCheck {
        var check = allocator.alloc(?uint, rows * cols * DirectionCardinality * RepeatCardinality) catch return ProblemErrors.AllocationFailed;
        for (0..rows) |i| {
            for (0..cols) |j| {
                for (0..DirectionCardinality) |dir| {
                    for (0..RepeatCardinality) |repeat| {
                        check[i * cols + j * DirectionCardinality + dir * RepeatCardinality + repeat] = null;
                    }
                }
            }
        }
        return NodeVisitCheck{ .check = check, .allocator = allocator, .cols = cols, .rows = rows };
    }

    fn get(self: NodeVisitCheck, next: Node) ?uint {
        return self.check[self.checkIndex(next)];
    }

    fn set(self: *NodeVisitCheck, next: Node, dist: uint) void {
        self.check[self.checkIndex(next)] = dist;
    }

    inline fn checkIndex(self: NodeVisitCheck, next: Node) usize {
        const perCol = RepeatCardinality * DirectionCardinality;
        const perRow = perCol * self.cols;
        return next.pos.i * perRow + next.pos.j * perCol + @as(usize, next.currentDirection.idx()) * RepeatCardinality + next.directionRepeat;
    }

    fn deinit(self: *NodeVisitCheck) void {
        self.allocator.free(self.check);
    }
};

const Node = struct {
    currentDirection: Direction,
    directionRepeat: u4,
    minRepeat: u4,
    maxRepeat: u4,
    pos: Position,
    dist: uint,

    /// Context is the target of the path finding
    const BinaryHeap = std.PriorityQueue(Node, Position, compare);

    /// Using manhattan distance to target as heuristic for AStar
    fn compare(target: Position, a: Node, b: Node) std.math.Order {
        const aToTarget = @max(a.pos.i, target.i) - @min(a.pos.i, target.i) + @max(a.pos.j, target.j) - @min(a.pos.j, target.j);
        const bToTarget = @max(b.pos.i, target.i) - @min(b.pos.i, target.i) + @max(b.pos.j, target.j) - @min(b.pos.j, target.j);
        return std.math.order(a.dist + aToTarget, b.dist + bToTarget);
    }

    fn neighbours(self: Node, grid: []const []const uint) [4]?Node {
        var res = [4]?Node{ null, null, null, null };
        for (Direction.all) |d| {
            if (!d.opposite().eql(self.currentDirection)) {
                const changeDirection = !d.eql(self.currentDirection);
                if ((changeDirection and self.directionRepeat >= self.minRepeat) or (!changeDirection and self.directionRepeat < self.maxRepeat)) {
                    const repeat = if (d.eql(self.currentDirection)) self.directionRepeat + 1 else 1;
                    const posOpt = movePosition(self.pos, d);
                    if (posOpt) |pos| {
                        if (pos.i >= 0 and pos.j >= 0 and pos.i < grid.len and pos.j < grid[0].len) {
                            res[d.idx()] = Node{ .currentDirection = d, .directionRepeat = repeat, .pos = pos, .dist = self.dist + grid[pos.i][pos.j], .minRepeat = self.minRepeat, .maxRepeat = self.maxRepeat };
                        }
                    }
                }
            }
        }
        return res;
    }
};

const Position = struct {
    i: usize,
    j: usize,

    fn make(i: usize, j: usize) Position {
        return Position{ .i = i, .j = j };
    }
};

const DirectionCardinality = 4;
const Direction = union(enum(u2)) {
    Left = 0,
    Up = 1,
    Right = 2,
    Down = 3,

    fn idx(self: Direction) u2 {
        return @intFromEnum(self);
    }

    fn get(self: Direction, T: type, slice: []T) T {
        return slice[self.idx()];
    }

    fn opposite(self: Direction) Direction {
        return switch (self) {
            .Left => .Right,
            .Right => .Left,
            .Up => .Down,
            .Down => .Up,
        };
    }

    fn eql(self: Direction, other: Direction) bool {
        return self.idx() == other.idx();
    }

    const all = [DirectionCardinality]Direction{ .Left, .Up, .Right, .Down };
};

fn movePosition(pos: Position, dir: Direction) ?Position {
    return switch (dir) {
        .Left => if (pos.j > 0) Position.make(pos.i, pos.j - 1) else null,
        .Right => Position.make(pos.i, pos.j + 1),
        .Up => if (pos.i > 0) Position.make(pos.i - 1, pos.j) else null,
        .Down => Position.make(pos.i + 1, pos.j),
    };
}

// Tests

test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/17.txt", solve_part_one);
    try std.testing.expectEqual(@as(uint, 845), res);
}

test "Golden Test Part Two" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/17.txt", solve_part_two);
    try std.testing.expectEqual(@as(uint, 993), res);
}

test "Example Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    try lines.append("2413432311323");
    try lines.append("3215453535623");
    try lines.append("3255245654254");
    try lines.append("3446585845452");
    try lines.append("4546657867536");
    try lines.append("1438598798454");
    try lines.append("4457876987766");
    try lines.append("3637877979653");
    try lines.append("4654967986887");
    try lines.append("4564679986453");
    try lines.append("1224686865563");
    try lines.append("2546548887735");
    try lines.append("4322674655533");
    defer lines.deinit();
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 102), res);
}

test "Example Part Two" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    try lines.append("2413432311323");
    try lines.append("3215453535623");
    try lines.append("3255245654254");
    try lines.append("3446585845452");
    try lines.append("4546657867536");
    try lines.append("1438598798454");
    try lines.append("4457876987766");
    try lines.append("3637877979653");
    try lines.append("4654967986887");
    try lines.append("4564679986453");
    try lines.append("1224686865563");
    try lines.append("2546548887735");
    try lines.append("4322674655533");
    defer lines.deinit();
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 94), res);
}

test "Example Bis Part Two" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    try lines.append("111111111111");
    try lines.append("999999999991");
    try lines.append("999999999991");
    try lines.append("999999999991");
    try lines.append("999999999991");
    defer lines.deinit();
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 71), res);
}
