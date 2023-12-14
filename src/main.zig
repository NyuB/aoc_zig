const std = @import("std");
const lib = @import("tests_lib.zig");
const solve = @import("aoc_2023_12.zig").solve_part_two;
pub fn main() !void {
    const res = try lib.for_lines_allocating(u64, std.heap.page_allocator, "problems/12.txt", solve);
    std.debug.print("Result = {d}\n", .{res});
}
