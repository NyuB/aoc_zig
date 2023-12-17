const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u32;
const ProblemErrors = error{ AllocationFailed, IllegalInput };

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    var grid = parseGrid(allocator, lines.items) catch unreachable;
    defer freeGrid(allocator, grid);
    const res = solve(allocator, grid) catch unreachable;
    return res;
}

pub fn solve_part_two(lines: std.ArrayList(String)) uint {
    // TODO Process problem input and apply your solver here
    _ = lines;
    return 42;
}

// Caller owns returned memory
fn parseGrid(allocator: std.mem.Allocator, lines: []const []const u8) ![][]const uint {
    const rows = lines.len;
    const cols = if (rows == 0) 0 else lines[0].len;
    var res = allocator.alloc([]uint, rows) catch return ProblemErrors.AllocationFailed;
    for (0..rows) |i| {
        res[i] = allocator.alloc(uint, cols) catch return ProblemErrors.AllocationFailed;
        for (0..cols) |j| {
            res[i][j] = std.fmt.parseInt(uint, lines[i][j .. j + 1], 10) catch return ProblemErrors.IllegalInput;
        }
    }
    return res;
}

fn freeGrid(allocator: std.mem.Allocator, grid: [][]const uint) void {
    for (grid) |row| {
        allocator.free(row);
    }
    allocator.free(grid);
}

fn solve(allocator: std.mem.Allocator, grid: []const []const uint) ProblemErrors!uint {
    const rows = grid.len;
    const cols = if (rows == 0) return ProblemErrors.IllegalInput else grid[0].len;
    const startDown = Node{ .currentDirection = Direction.Down, .directionRepeat = 1, .pos = Position.make(1, 0), .dist = grid[1][0] };
    const startRight = Node{ .currentDirection = Direction.Right, .directionRepeat = 1, .pos = Position.make(0, 1), .dist = grid[0][1] };
    var q = Node.BinaryHeap.init(allocator, Position.make(rows - 1, cols - 1));
    q.add(startDown) catch return ProblemErrors.AllocationFailed;
    q.add(startRight) catch return ProblemErrors.AllocationFailed;
    defer q.deinit();
    var check = try NodeVisitCheck.init(allocator, rows, cols);
    defer check.deinit();

    while (q.removeOrNull()) |n| {
        if (n.pos.i == rows - 1 and n.pos.j == cols - 1) return n.dist;
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

    fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) ProblemErrors!NodeVisitCheck {
        var check = allocator.alloc(?uint, rows * cols * 4 * 4) catch return ProblemErrors.AllocationFailed;
        for (0..rows) |i| {
            for (0..cols) |j| {
                for (0..4) |dir| {
                    for (0..4) |repeat| {
                        check[i * cols + j * 4 + dir * 4 + repeat] = null;
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
        const perDirection = 4;
        const perCol = perDirection * 4;
        const perRow = perCol * self.cols;

        return next.pos.i * perRow + next.pos.j * perCol + @as(usize, next.currentDirection.idx()) * perDirection + next.directionRepeat;
    }

    fn deinit(self: *NodeVisitCheck) void {
        self.allocator.free(self.check);
    }
};

const Node = struct {
    currentDirection: Direction,
    directionRepeat: u2,
    pos: Position,
    dist: uint,

    const BinaryHeap = std.PriorityQueue(Node, Position, compare);

    // manhattan heuristic for AStar
    fn compare(target: Position, a: Node, b: Node) std.math.Order {
        const aToTarget = @max(a.pos.i, target.i) - @min(a.pos.i, target.i) + @max(a.pos.j, target.j) - @min(a.pos.j, target.j);
        const bToTarget = @max(b.pos.i, target.i) - @min(b.pos.i, target.i) + @max(b.pos.j, target.j) - @min(b.pos.j, target.j);
        return std.math.order(a.dist + aToTarget, b.dist + bToTarget);
    }

    fn neighbours(self: Node, grid: []const []const uint) [4]?Node {
        var res = [4]?Node{ null, null, null, null };
        for (Direction.all, 0..) |d, i| {
            if (!d.opposite().eql(self.currentDirection)) {
                if (!d.eql(self.currentDirection) or self.directionRepeat < 3) {
                    const repeat = if (d.eql(self.currentDirection)) self.directionRepeat + 1 else 1;
                    const posOpt = movePosition(self.pos, d);
                    if (posOpt) |pos| {
                        if (pos.i >= 0 and pos.j >= 0 and pos.i < grid.len and pos.j < grid[0].len) {
                            res[i] = Node{ .currentDirection = d, .directionRepeat = repeat, .pos = pos, .dist = self.dist + grid[pos.i][pos.j] };
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

    const all = [4]Direction{ .Left, .Up, .Right, .Down };
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
    try std.testing.expectEqual(@as(uint, 0), res);
}

test "Golden Test Part Two" {
    // TODO Test solve_part_two on your actual problem input here
    // You may use for_lines or for_lines_allocating from tests_lib.zig
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
    // TODO Test solve_part_two on the problem example here
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    const res = solve_part_two(lines);
    try std.testing.expectEqual(@as(uint, 42), res);
}
