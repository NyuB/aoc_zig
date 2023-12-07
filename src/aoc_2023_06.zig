const std = @import("std");
const lib = @import("tests_lib.zig");
const String = lib.String;
const int = i64;
const float = f64;

fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) int {
    var times = lib.split_str_on_blanks(allocator, lines.items[0]) catch unreachable;
    defer times.deinit();
    var records = lib.split_str_on_blanks(allocator, lines.items[1]) catch unreachable;
    defer records.deinit();
    var res: ?int = null;
    for (1..times.items.len) |i| {
        const t = lib.num_of_string_exn(int, times.items[i]);
        const record = lib.num_of_string_exn(int, records.items[i]);
        const solution = solve(record + 1, t) orelse unreachable;
        const count = solution[1] - solution[0] + 1;
        if (res) |r| {
            res = r * count;
        } else {
            res = count;
        }
    }
    return res orelse unreachable;
}

fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) int {
    var times = lib.split_str_on_blanks(allocator, lines.items[0]) catch unreachable;
    defer times.deinit();
    var records = lib.split_str_on_blanks(allocator, lines.items[1]) catch unreachable;
    defer records.deinit();
    const concatTimes = lib.join(allocator, "", times.items[1..]) catch unreachable;
    defer concatTimes.deinit();
    const t = lib.num_of_string_exn(int, concatTimes.items);
    const concatRecords = lib.join(allocator, "", records.items[1..]) catch unreachable;
    defer concatRecords.deinit();
    const record = lib.num_of_string_exn(int, concatRecords.items);
    const solution = solve(record + 1, t) orelse unreachable;
    return solution[1] - solution[0] + 1;
}

/// -h² + th
///
/// where h = `hold`
fn totalDistance(t: int, hold: int) int {
    return (t - hold) * hold;
}

/// Solve -h² + th - r = 0
///
/// where r = `bestRecord`
///
/// returns two extremas, between these h allows to reach the record
///
/// **null** result means the equation is unsolvable, and the record unreachable
fn solve(bestRecord: int, t: int) ?[2]int {
    const bestRecordFloating: float = @floatFromInt(bestRecord);
    const tFloating: float = @floatFromInt(t);
    const delta: float = (tFloating * tFloating) - 4.0 * bestRecordFloating;
    if (delta < 0) return null;
    const a = (-tFloating - @sqrt(delta)) / (-2.0);
    const b = (-tFloating + @sqrt(delta)) / (-2.0);
    const leftSolution = @ceil(@min(a, b));
    const rightSolution = @floor(@max(a, b));
    return [_]int{ @intFromFloat(leftSolution), @intFromFloat(rightSolution) };
}

test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(int, std.testing.allocator, "problems/06.txt", solve_part_one);
    try std.testing.expectEqual(@as(int, 2269432), res);
}

test "Golden Test Part Two" {
    const res = try lib.for_lines_allocating(int, std.testing.allocator, "problems/06.txt", solve_part_two);
    try std.testing.expectEqual(@as(int, 35865985), res);
}

test "Example Part One" {
    var lines = try example();
    defer lines.deinit();
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(int, 288), res);
}

test "Example Part Two" {
    var lines = try example();
    defer lines.deinit();
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(int, 71503), res);
}

test "Solve 2nd° polynomials: r = 0" {
    const res = solve(0, 7) orelse unreachable;
    try std.testing.expectEqual(@as(int, 0), res[0]);
    try std.testing.expectEqual(@as(int, 7), res[1]);
}

test "Solve 2nd° polynomials (AOC example) t = 7, r = 9" {
    const res = solve(9, 7) orelse unreachable;
    try std.testing.expectEqual(@as(int, 2), res[0]);
    try std.testing.expectEqual(@as(int, 5), res[1]);
}

fn example() !std.ArrayList(String) {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    try lines.append("Time:      7  15   30");
    try lines.append("Distance:  9  40  200");
    return lines;
}
