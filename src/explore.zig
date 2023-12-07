//! Exploring zig syntax and concepts

const std = @import("std");
const expect = std.testing.expect;
test "In place mutation" {
    var b = true;
    negateInPlace(&b);
    try std.testing.expectEqual(false, b);
}

fn negateInPlace(b: *bool) void {
    b.* = !b.*;
}
// Example from ziglearn https://ziglearn.org/chapter-4/
const Data = extern struct { a: i32, b: u8, c: f32, d: bool, e: bool };
test "data alignment" {
    const x = Data{
        .a = 10005,
        .b = 42,
        .c = -10.5,
        .d = false,
        .e = true,
    };
    const z = @as([*]const u8, @ptrCast(&x));
    try expect(@sizeOf(Data) == 16);
    try expect(@as(*const i32, @ptrCast(@alignCast(z))).* == 10005);
    try expect(@as(*const u8, @ptrCast(@alignCast(z + 4))).* == 42);
    try expect(@as(*const f32, @ptrCast(@alignCast(z + 8))).* == -10.5);
    try expect(@as(*const bool, @ptrCast(@alignCast(z + 12))).* == false);
    try expect(@as(*const bool, @ptrCast(@alignCast(z + 13))).* == true);
}

const ReorderedData = extern struct { a: i32, c: f32, b: u8, d: bool, e: bool };
test "even reordered, data size must be a multiple of 8" {
    try expect(@sizeOf(Data) == 16);
}
