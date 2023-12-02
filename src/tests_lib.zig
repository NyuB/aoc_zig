const std = @import("std");
pub const String = []const u8;
pub const Path = []const u8;

pub fn for_lines(comptime ReturnType: type, comptime file_path: Path, comptime Fun: *const fn (std.ArrayList(String)) ReturnType) !ReturnType {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();

    var buf_reader = std.io.bufferedReader(file.reader());
    var read_stream = buf_reader.reader();
    var buf_writer: [9000]u8 = undefined;
    var write_stream = std.io.fixedBufferStream(&buf_writer);

    read_stream.streamUntilDelimiter(write_stream.writer(), '\n', @as(?usize, null)) catch {};
    while (try write_stream.getPos() > 0) {
        const line = write_stream.getWritten();
        const line_copy: []u8 = try std.testing.allocator.alloc(u8, line.len);
        std.mem.copy(u8, line_copy, line);
        try lines.append(line_copy);
        write_stream.reset();
        read_stream.streamUntilDelimiter(write_stream.writer(), '\n', @as(?usize, null)) catch {};
    }

    defer {
        for (lines.items) |line| {
            std.testing.allocator.free(line);
        }
    }
    return Fun(lines);
}

pub fn starts_with(prefix: String, s: String) bool {
    if (prefix.len > s.len) {
        return false;
    }
    for (prefix, 0..) |value, index| {
        if (s[index] != value) {
            return false;
        }
    }
    return true;
}

pub fn split_str(allocator: std.mem.Allocator, s: String, comptime delimiter: String) !std.ArrayList(String) {
    comptime if (delimiter.len == 0) {
        @compileError("Forbidden usage of empty delimiter");
    };
    var result = std.ArrayList(String).init(allocator);
    var it = std.mem.splitSequence(u8, s, delimiter);
    while (it.next()) |i| {
        try result.append(i);
    }
    return result;
}

pub fn split_str_exn(allocator: std.mem.Allocator, s: String, comptime delimiter: String) std.ArrayList(String) {
    return split_str(allocator, s, delimiter) catch unreachable;
}

pub fn int_of_string_exn(s: String) i32 {
    return std.fmt.parseInt(i32, s, 10) catch unreachable;
}

test "Split on ' '" {
    const res = try split_str(std.testing.allocator, "Ho ho hO", " ");
    defer res.deinit();
    try std.testing.expectEqual(@as(usize, 3), res.items.len);
    try std.testing.expectEqualStrings("Ho", res.items[0]);
    try std.testing.expectEqualStrings("ho", res.items[1]);
    try std.testing.expectEqualStrings("hO", res.items[2]);
}

test "Split empty string" {
    const res = try split_str(std.testing.allocator, "", " ");
    defer res.deinit();
    try std.testing.expectEqual(@as(usize, 1), res.items.len);
    try std.testing.expectEqualStrings("", res.items[0]);
}

test "Split no delimiter occurence in string" {
    const res = try split_str(std.testing.allocator, "ABC", ";");
    defer res.deinit();
    try std.testing.expectEqual(@as(usize, 1), res.items.len);
    try std.testing.expectEqualStrings("ABC", res.items[0]);
}
