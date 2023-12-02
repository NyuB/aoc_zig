const std = @import("std");
const lib = @import("tests_lib.zig");
const String = lib.String;

pub fn solve_part_one(lines: std.ArrayList(String)) i32 {
    var sum: i32 = 0;
    for (lines.items) |s| {
        sum += code_of_line_one(s);
    }
    return sum;
}

pub fn solve_part_two(lines: std.ArrayList(String)) i32 {
    var sum: i32 = 0;
    for (lines.items) |s| {
        sum += code_of_line_two(s);
    }
    return sum;
}

fn code_of_line_one(s: String) i32 {
    const first_last = digits_of_string(s);
    return first_last[0] * 10 + first_last[1];
}

fn code_of_line_two(s: String) i32 {
    const first_last = digit_likes_of_string(s);
    return first_last[0] * 10 + first_last[1];
}

fn digit(c: u8) u8 {
    return switch (c) {
        '1' => 1,
        '2' => 2,
        '3' => 3,
        '4' => 4,
        '5' => 5,
        '6' => 6,
        '7' => 7,
        '8' => 8,
        '9' => 9,
        else => 0,
    };
}

fn digits_of_string(s: String) [2]u8 {
    var first: u8 = 0;
    var last: u8 = 0;
    for (s) |c| {
        const d = digit(c);
        if (d > 0) {
            if (first == 0) {
                first = d;
            }
            last = d;
        }
    }
    return [2]u8{ first, last };
}

fn digit_likes_of_string(s: String) [2]u8 {
    var first: u8 = 0;
    var last: u8 = 0;
    for (s, 0..) |c, index| {
        var d = digit(c);
        const sub_string = s[index..];
        if (starts_with("one", sub_string)) {
            d = 1;
        } else if (starts_with("two", sub_string)) {
            d = 2;
        } else if (starts_with("three", sub_string)) {
            d = 3;
        } else if (starts_with("four", sub_string)) {
            d = 4;
        } else if (starts_with("five", sub_string)) {
            d = 5;
        } else if (starts_with("six", sub_string)) {
            d = 6;
        } else if (starts_with("seven", sub_string)) {
            d = 7;
        } else if (starts_with("eight", sub_string)) {
            d = 8;
        } else if (starts_with("nine", sub_string)) {
            d = 9;
        }
        if (d > 0) {
            if (first == 0) {
                first = d;
            }
            last = d;
        }
    }
    return [2]u8{ first, last };
}

fn starts_with(prefix: String, suffix: String) bool {
    if (prefix.len > suffix.len) {
        return false;
    }
    for (prefix, 0..) |value, index| {
        if (suffix[index] != value) {
            return false;
        }
    }
    return true;
}

// Tests
test "Golden test Part One" {
    const expected = 53651;
    const actual = try lib.for_lines(i32, "problems/01.txt", solve_part_one);
    try std.testing.expectEqual(@as(i32, expected), actual);
}

test "Golden test Part Two" {
    const expected = 53894;
    const actual = try lib.for_lines(i32, "problems/01.txt", solve_part_two);
    try std.testing.expectEqual(@as(i32, expected), actual);
}

test "Example Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("1abc2");
    try lines.append("pqr3stu8vwx");
    try lines.append("a1b2c3d4e5f");
    try lines.append("treb7uchet");
    const expected: i32 = 142;
    const actual: i32 = solve_part_one(lines);
    try std.testing.expectEqual(expected, actual);
}

test "Single digit" {
    try std.testing.expectEqual(@as(i32, 11), code_of_line_one("1"));
    try std.testing.expectEqual(@as(i32, 22), code_of_line_one("2"));
    try std.testing.expectEqual(@as(i32, 33), code_of_line_one("3"));
    try std.testing.expectEqual(@as(i32, 44), code_of_line_one("4"));
    try std.testing.expectEqual(@as(i32, 55), code_of_line_one("5"));
    try std.testing.expectEqual(@as(i32, 66), code_of_line_one("6"));
    try std.testing.expectEqual(@as(i32, 77), code_of_line_one("7"));
    try std.testing.expectEqual(@as(i32, 88), code_of_line_one("8"));
    try std.testing.expectEqual(@as(i32, 99), code_of_line_one("9"));
    try std.testing.expectEqual(@as(i32, 0), code_of_line_one("0"));
    try std.testing.expectEqual(@as(i32, 0), code_of_line_one(""));
}

test "Two digits" {
    try std.testing.expectEqual(@as(i32, 21), code_of_line_one("21"));
    try std.testing.expectEqual(@as(i32, 32), code_of_line_one("32"));
    try std.testing.expectEqual(@as(i32, 43), code_of_line_one("43"));
    try std.testing.expectEqual(@as(i32, 54), code_of_line_one("54"));
}

test "Middle digits" {
    try std.testing.expectEqual(@as(i32, 13), code_of_line_one("123"));
    try std.testing.expectEqual(@as(i32, 24), code_of_line_one("234"));
    try std.testing.expectEqual(@as(i32, 14), code_of_line_one("1234"));
}

test "Mixed with letters" {
    try std.testing.expectEqual(@as(i32, 13), code_of_line_one("1a2bc3de"));
    try std.testing.expectEqual(@as(i32, 13), code_of_line_one("1a2bcde3"));
    try std.testing.expectEqual(@as(i32, 13), code_of_line_one("a12bc3de"));
    try std.testing.expectEqual(@as(i32, 13), code_of_line_one("a12bcde3"));
}
