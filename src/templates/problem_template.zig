const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // skip program name
    const ignoredProgramName = args.next();
    _ = ignoredProgramName;

    const yearArg = args.next() orelse return Error.MissingYearArgument;
    const dayArg = args.next() orelse return Error.MissingDayArgument;
    const year = std.fmt.parseInt(u16, yearArg, 10) catch return Error.InvalidYear;
    const day = std.fmt.parseInt(u8, dayArg, 10) catch return Error.InvalidDay;
    const validatedDay = switch (Day.make(day, year)) {
        .InvalidDay => return Error.InvalidDay,
        .InvalidYear => return Error.InvalidYear,
        .Valid => |d| d,
    };

    var outputPath = try problemFilename(allocator, validatedDay);
    defer allocator.free(outputPath);

    const content = @embedFile("aoc_yyyy_dd.zig");

    var file = try std.fs.cwd().createFile(outputPath, .{});
    defer file.close();
    try file.writeAll(content);
}

const Error = error{ InvalidDay, InvalidYear, MissingDayArgument, MissingYearArgument };

const Day = struct {
    day: u8,
    year: u16,
    const Validation = union(enum) {
        Valid: Day,
        InvalidYear,
        InvalidDay,
    };
    fn make(day: u8, year: u16) Validation {
        if (day > 25) return Validation.InvalidDay;
        if (year < 2015 or year > 9999) return Validation.InvalidYear;
        return Validation{ .Valid = Day{ .year = year, .day = day } };
    }
};

fn problemFilename(allocator: std.mem.Allocator, day: Day) ![]u8 {
    var result = try allocator.alloc(u8, comptime ("src/aoc_yyyy_dd.zig".len));
    var writerContext = LimitedArrayWriter{ .array = result };
    var writer = std.io.Writer(*LimitedArrayWriter, LimitedArrayWriter.WriteError, LimitedArrayWriter.writeFn){ .context = &writerContext };

    const y4 = day.year % 10;
    const y3 = (day.year / 10) % 10;
    const y2 = (day.year / 100) % 10;
    const y1 = (day.year / 1000) % 10;

    const d2 = day.day % 10;
    const d1 = day.day / 10;

    try std.fmt.format(writer, "src/aoc_{d}{d}{d}{d}_{d}{d}.zig", .{ y1, y2, y3, y4, d1, d2 });
    return result;
}

const LimitedArrayWriter = struct {
    array: []u8,
    const WriteError = error{};
    fn writeFn(self: *LimitedArrayWriter, bytes: []const u8) WriteError!usize {
        const writeSize = @min(self.array.len, bytes.len);
        for (0..writeSize) |i| {
            self.array[i] = bytes[i];
        }
        if (self.array.len > writeSize) self.array = self.array[writeSize..];
        return writeSize;
    }
};

test "Problem format" {
    var s = try problemFilename(std.testing.allocator, Day{ .year = 2023, .day = 15 });
    defer std.testing.allocator.free(s);
    try std.testing.expectEqualStrings("src/aoc_2023_15.zig", s);
}
