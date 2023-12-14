const std = @import("std");
pub const String = []const u8;
pub const Path = []const u8;

pub fn for_lines(comptime ReturnType: type, comptime file_path: Path, comptime Fun: *const fn (std.ArrayList(String)) ReturnType) !ReturnType {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();

    defer {
        for (lines.items) |line| {
            std.testing.allocator.free(line);
        }
    }

    var buf_reader = std.io.bufferedReader(file.reader());
    var read_stream = buf_reader.reader();
    var buf_writer: [9000]u8 = undefined;
    var write_stream = std.io.fixedBufferStream(&buf_writer);

    streamUntilEolOrEof(read_stream, write_stream.writer()) catch {};
    while (true) {
        const line = write_stream.getWritten();
        const line_copy: []u8 = try std.testing.allocator.alloc(u8, line.len);
        std.mem.copy(u8, line_copy, line);
        try lines.append(line_copy);
        write_stream.reset();
        streamUntilEolOrEof(read_stream, write_stream.writer()) catch {
            const lastLine = write_stream.getWritten();
            if (lastLine.len > 0) {
                const lastLineCopy: []u8 = try std.testing.allocator.alloc(u8, lastLine.len);
                std.mem.copy(u8, lastLineCopy, lastLine);
                try lines.append(lastLineCopy);
            }

            return Fun(lines);
        };
    }
    unreachable;
}

pub fn for_lines_allocating(comptime ReturnType: type, allocator: std.mem.Allocator, comptime file_path: Path, comptime Fun: *const fn (std.mem.Allocator, std.ArrayList(String)) ReturnType) !ReturnType {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();
    var lines = std.ArrayList(String).init(allocator);
    defer lines.deinit();
    defer {
        for (lines.items) |line| {
            allocator.free(line);
        }
    }

    var buf_reader = std.io.bufferedReader(file.reader());
    var read_stream = buf_reader.reader();
    var buf_writer: [9000]u8 = undefined;
    var write_stream = std.io.fixedBufferStream(&buf_writer);

    streamUntilEolOrEof(read_stream, write_stream.writer()) catch {};
    while (true) {
        const line = write_stream.getWritten();
        const line_copy: []u8 = try allocator.alloc(u8, line.len);
        std.mem.copy(u8, line_copy, line);
        try lines.append(line_copy);
        write_stream.reset();
        streamUntilEolOrEof(read_stream, write_stream.writer()) catch {
            const lastLine = write_stream.getWritten();
            if (lastLine.len > 0) {
                const lastLineCopy: []u8 = try allocator.alloc(u8, lastLine.len);
                std.mem.copy(u8, lastLineCopy, lastLine);
                try lines.append(lastLineCopy);
            }

            return Fun(allocator, lines);
        };
    }
    unreachable;
}

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

pub fn streamUntilEolOrEof(reader: anytype, writer: anytype) !void {
    while (true) {
        const byte: u8 = try reader.readByte(); // (Error || error{EndOfStream})
        if (byte == '\n') return;
        if (byte == '\r') continue;
        try writer.writeByte(byte); // @TypeOf(writer).Error
    }
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

pub fn firstItem(items: anytype) itemTypeOf(items) {
    return items[0];
}

test "firstItem" {
    const items = [_]u32{ 1, 2, 3, 4 };
    const strItems = [_]String{ "A", "B", "C" };
    try std.testing.expect(firstItem(&items) == 1);
    try std.testing.expect(firstItem(items) == 1);
    try std.testing.expectEqualStrings(firstItem(&strItems), "A");
    try std.testing.expectEqualStrings(firstItem(strItems), "A");
}

pub fn lastItem(items: anytype) itemTypeOf(items) {
    return items[items.len - 1];
}

test "lastItem" {
    const items = [_]u32{ 1, 2, 3, 4 };
    const strItems = [_]String{ "A", "B", "C" };
    try std.testing.expect(lastItem(&items) == 4);
    try std.testing.expect(lastItem(items) == 4);
    try std.testing.expectEqualStrings(lastItem(&strItems), "C");
    try std.testing.expectEqualStrings(lastItem(strItems), "C");
}

fn itemTypeOf(comptime items: anytype) type {
    return switch (@typeInfo(@TypeOf(items))) {
        .Pointer => |p| @typeInfo(p.child).Array.child,
        .Array => |a| a.child,
        inline else => @compileError("Unsupported type for last item"),
    };
}

pub fn split_str(allocator: std.mem.Allocator, s: String, comptime delimiter: String) !std.ArrayList(String) {
    comptime if (delimiter.len == 0) {
        @compileError("Forbidden usage of empty delimiter");
    };
    var result = std.ArrayList(String).init(allocator);
    errdefer result.deinit();
    var it = std.mem.splitSequence(u8, s, delimiter);
    while (it.next()) |i| {
        try result.append(i);
    }
    return result;
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

test "split_n_str 2 delimiters 3 items asked" {
    const res = split_n_str(3, "A;B", ";");
    try std.testing.expectEqualStrings("A", res[0] orelse unreachable);
    try std.testing.expectEqualStrings("B", res[1] orelse unreachable);
    try std.testing.expectEqual(@as(?String, null), res[2]);
}

pub fn split_str_on_blanks(allocator: std.mem.Allocator, s: String) !std.ArrayList(String) {
    var res = std.ArrayList(String).init(allocator);
    var start: usize = 0;
    var end = start;
    while (end < s.len) {
        if (s[end] == ' ' or s[end] == '\t') {
            if (start != end) {
                try res.append(s[start..end]);
            }
            end += 1;
            start = end;
        } else {
            end += 1;
        }
    }
    if (start != end) {
        try res.append(s[start..end]);
    }
    return res;
}

test "Split on blanks" {
    const evenlySpaced = "0 1 2";
    const multipleSpacing = " 0 1     2 ";
    const evenlySplit = try split_str_on_blanks(std.testing.allocator, evenlySpaced);
    defer evenlySplit.deinit();
    const multipleSplit = try split_str_on_blanks(std.testing.allocator, multipleSpacing);
    defer multipleSplit.deinit();
    try std.testing.expectEqualStrings("0", evenlySplit.items[0]);
    try std.testing.expectEqualStrings("1", evenlySplit.items[1]);
    try std.testing.expectEqualStrings("2", evenlySplit.items[2]);

    try std.testing.expectEqualStrings("0", multipleSplit.items[0]);
    try std.testing.expectEqualStrings("1", multipleSplit.items[1]);
    try std.testing.expectEqualStrings("2", multipleSplit.items[2]);
}

pub fn join(allocator: std.mem.Allocator, comptime separator: String, strings: []String) !std.ArrayList(u8) {
    var res = std.ArrayList(u8).init(allocator);
    if (strings.len == 0) return res;
    try res.appendSlice(strings[0]);

    for (1..strings.len) |i| {
        try std.fmt.format(res.writer(), "{s}{s}", .{ separator, strings[i] });
    }
    return res;
}

test "Join strings" {
    var strings = std.ArrayList(String).init(std.testing.allocator);
    defer strings.deinit();
    try strings.append("One");
    try strings.append("Two");
    try strings.append("Three");
    var buffer = try join(std.testing.allocator, "< | >", strings.items);
    defer buffer.deinit();
    try std.testing.expectEqualStrings(buffer.items, "One< | >Two< | >Three");
}

pub fn split_str_exn(allocator: std.mem.Allocator, s: String, comptime delimiter: String) std.ArrayList(String) {
    return split_str(allocator, s, delimiter) catch unreachable;
}

pub fn int_of_string_exn(s: String) i32 {
    return std.fmt.parseInt(i32, s, 10) catch unreachable;
}

pub fn num_of_string_exn(comptime t: type, s: String) t {
    return std.fmt.parseInt(t, s, 10) catch unreachable;
}

pub fn uint_of_usize(comptime uint: type, u: usize) uint {
    return @as(uint, @intCast(u));
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
