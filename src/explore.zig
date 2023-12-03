//! Exploring zig syntax and concepts

const std = @import("std");

test "In place mutation" {
    var b = true;
    negateInPlace(&b);
    try std.testing.expectEqual(false, b);
}

fn negateInPlace(b: *bool) void {
    b.* = !b.*;
}
