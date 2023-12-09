const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const int = i32;

const ProblemError = error{AllocationError};

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) int {
    return solve(allocator, lines, completeLast);
}

pub fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) int {
    return solve(allocator, lines, completeFirst);
}

fn solve(allocator: std.mem.Allocator, lines: std.ArrayList(String), comptime Solver: fn (std.mem.Allocator, int, []const int) ProblemError!int) int {
    var res: int = 0;
    for (lines.items) |l| {
        var values = std.ArrayList(int).init(allocator);
        defer values.deinit();
        var intStr = lib.split_str(allocator, l, " ") catch unreachable;
        defer intStr.deinit();
        for (intStr.items) |s| {
            values.append(lib.int_of_string_exn(s)) catch unreachable;
        }
        res += Solver(allocator, 0, values.items) catch unreachable;
    }
    return res;
}

fn completeLast(allocator: std.mem.Allocator, lastValue: int, values: []const int) ProblemError!int {
    var last: int = values[0];
    var constant: bool = true;
    var next = std.ArrayList(int).init(allocator);
    defer next.deinit();
    for (values[1..]) |v| {
        const diff = v - last;
        next.append(diff) catch return ProblemError.AllocationError;
        constant = constant and last == v;
        last = v;
    }
    if (constant) {
        return lastValue + last + next.getLast();
    } else {
        return completeLast(allocator, lastValue + last, next.items);
    }
}

fn completeFirst(allocator: std.mem.Allocator, firstValue: int, values: []const int) ProblemError!int {
    const reversedValues = reversed(allocator, values) catch return ProblemError.AllocationError;
    defer allocator.free(reversedValues);
    return try completeLast(allocator, firstValue, reversedValues);
}

/// Caller owns returned memory
fn reversed(allocator: std.mem.Allocator, items: []const int) ![]const int {
    const copy = try allocator.alloc(int, items.len);
    for (items, 0..) |v, i| {
        copy[copy.len - 1 - i] = v;
    }
    return copy;
}

// Tests

test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(int, std.testing.allocator, "problems/09.txt", solve_part_one);
    try std.testing.expectEqual(@as(int, 1641934234), res);
}

test "Golden Test Part Two" {
    const res = try lib.for_lines_allocating(int, std.testing.allocator, "problems/09.txt", solve_part_two);
    try std.testing.expectEqual(@as(int, 975), res);
}

test "Example Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();

    try lines.append("0 3 6 9 12 15");
    try lines.append("1 3 6 10 15 21");
    try lines.append("10 13 16 21 30 45");

    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(int, 114), res);
}

test "Example Part Two" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();

    try lines.append("0 3 6 9 12 15");
    try lines.append("1 3 6 10 15 21");
    try lines.append("10 13 16 21 30 45");

    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(int, 2), res);
}

test "completeLast() examples" {
    const firstHistory = [_]int{ 0, 3, 6, 9, 12, 15 };
    const firstResult = try completeLast(std.testing.allocator, 0, &firstHistory);

    const secondHistory = [_]int{ 1, 3, 6, 10, 15, 21 };
    const secondResult = try completeLast(std.testing.allocator, 0, &secondHistory);

    const thirdHistory = [_]int{ 10, 13, 16, 21, 30, 45 };
    const thirdResult = try completeLast(std.testing.allocator, 0, &thirdHistory);

    try std.testing.expectEqual(@as(int, 18), firstResult);
    try std.testing.expectEqual(@as(int, 28), secondResult);
    try std.testing.expectEqual(@as(int, 68), thirdResult);
}

test "completeFirst() example" {
    const firstHistory = [_]int{ 0, 3, 6, 9, 12, 15 };
    const firstResult = try completeFirst(std.testing.allocator, 0, &firstHistory);

    const secondHistory = [_]int{ 1, 3, 6, 10, 15, 21 };
    const secondResult = try completeFirst(std.testing.allocator, 0, &secondHistory);

    const thirdHistory = [_]int{ 10, 13, 16, 21, 30, 45 };
    const thirdResult = try completeFirst(std.testing.allocator, 0, &thirdHistory);

    try std.testing.expectEqual(@as(int, -3), firstResult);
    try std.testing.expectEqual(@as(int, 0), secondResult);
    try std.testing.expectEqual(@as(int, 5), thirdResult);
}
