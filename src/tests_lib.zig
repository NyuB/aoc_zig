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
