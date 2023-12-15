const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u32;
const ProblemErrors = error{AllocationFailed};

pub fn solve_part_one(lines: std.ArrayList(String)) uint {
    // TODO Process problem input and apply your solver here
    _ = lines;
    return 42;
}

pub fn solve_part_two(lines: std.ArrayList(String)) uint {
    // TODO Process problem input and apply your solver here
    _ = lines;
    return 42;
}

// Tests
test "Golden Test Part One" {
    // TODO Test solve_part_one on your actual problem input here
    // You may use for_lines or for_lines_allocating from tests_lib.zig
}

test "Golden Test Part Two" {
    // TODO Test solve_part_two on your actual problem input here
    // You may use for_lines or for_lines_allocating from tests_lib.zig
}

test "Example Part One" {
    // TODO Test solve_part_one on the problem example here
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    const res = solve_part_one(lines);
    try std.testing.expectEqual(@as(uint, 42), res);
}

test "Example Part Two" {
    // TODO Test solve_part_two on the problem example here
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    const res = solve_part_two(lines);
    try std.testing.expectEqual(@as(uint, 42), res);
}
