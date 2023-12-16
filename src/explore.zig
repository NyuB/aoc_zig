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

test "FreeMe of string" {
    var s = try makeString(std.testing.allocator, 'A', 12);
    defer s.deinit();
    try std.testing.expectEqualStrings("AAAAAAAAAAAA", s.t);
}

fn makeString(allocator: std.mem.Allocator, c: u8, n: usize) !FreeMe([]const u8) {
    var res = try allocator.alloc(u8, n);
    for (0..n) |i| res[i] = c;
    return FreeMe([]const u8).init(res, allocator);
}

fn FreeMe(comptime T: type) type {
    return struct {
        t: T,
        allocator: std.mem.Allocator,
        const Self = @This();
        fn deinit(self: *Self) void {
            self.allocator.free(self.t);
        }

        fn init(t: T, allocator: std.mem.Allocator) Self {
            return .{ .t = t, .allocator = allocator };
        }
    };
}
