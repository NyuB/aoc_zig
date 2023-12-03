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

pub fn for_lines_allocating(comptime ReturnType: type, allocator: std.mem.Allocator, comptime file_path: Path, comptime Fun: *const fn (std.mem.Allocator, std.ArrayList(String)) ReturnType) !ReturnType {
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
        const line_copy: []u8 = try allocator.alloc(u8, line.len);
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
    return Fun(allocator, lines);
}

pub fn fold_left(comptime Result: type, comptime Item: type, comptime Reduce: *const fn (Result, Item) Result, init: Result, items: []Item) Result {
    var res = init;
    for (items) |item| {
        res = Reduce(res, item);
    }
    return res;
}

pub fn any(comptime Item: type, comptime Predicate: *const fn (Item) bool, items: []Item) bool {
    for (items) |item| {
        if (Predicate(item)) {
            return true;
        }
    }
    return false;
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

/// Return the `n`first parts of a split of the string `s` on `delimiter`
///
/// `delimiter` must be non-empty
///
/// Examples
///
/// split_n_str(2, "A; B; C", "; ") <=> { "A", "B" }
///
/// split_n_str(3, "A; B", "; ") <=> { "A", "B", null }
pub fn split_n_str(comptime n: usize, s: String, comptime delimiter: String) [n]?String {
    comptime if (delimiter.len == 0) {
        @compileError("Forbidden usage of empty delimiter");
    };
    var res: [n]?String = undefined;
    var it = std.mem.splitSequence(u8, s, delimiter);
    for (0..n) |i| {
        if (it.next()) |sub_str| {
            res[i] = sub_str;
        } else {
            res[i] = null;
        }
    }
    return res;
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

test "split_n_str no delimiter ocurrence" {
    const res = split_n_str(2, "ABC", ";");
    try std.testing.expectEqualStrings("ABC", res[0] orelse unreachable);
    try std.testing.expectEqual(res[1], null);
}

test "split_n_str 2 delimiters 2 items asked" {
    const res = split_n_str(2, "A;B;C", ";");
    try std.testing.expectEqualStrings("A", res[0] orelse unreachable);
    try std.testing.expectEqualStrings("B", res[1] orelse unreachable);
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

// Tests correct lines splitting. In case of error of 1 character offset, check if your files do not end with CRLF instead of LF ...
test "For lines" {
    const lines_count = try for_lines(usize, "problems/sample.txt", count_lines);
    const lines_len = try for_lines(usize, "problems/sample.txt", first_line_len);
    const lines_len_alloc = try for_lines_allocating(usize, std.testing.allocator, "problems/sample.txt", first_line_len_alloc);
    const lines_len_alloc_03 = try for_lines_allocating(usize, std.testing.allocator, "problems/03.txt", first_line_len_alloc);
    try std.testing.expectEqual(@as(usize, 2), lines_count);
    try std.testing.expectEqual(@as(usize, 9), lines_len);
    try std.testing.expectEqual(@as(usize, 9), lines_len_alloc);
    try std.testing.expectEqual(@as(usize, 140), lines_len_alloc_03);
}

fn count_lines(lines: std.ArrayList(String)) usize {
    return lines.items.len;
}

fn first_line_len(lines: std.ArrayList(String)) usize {
    return lines.items[0].len;
}

fn first_line_len_alloc(ingored_alloc: std.mem.Allocator, lines: std.ArrayList(String)) usize {
    _ = ingored_alloc;
    return lines.items[0].len;
}
