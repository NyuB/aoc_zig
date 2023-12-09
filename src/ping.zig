const std = @import("std");
const os = std.os;
const sok = @import("sok.zig");

pub fn main() !void {

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var client = try sok.UDPClient.initIp4(.{ 127, 0, 0, 1 }, 8888);
    defer client.close();

    try stdout.print("SOK UDPing !\n", .{});
    const messages = [_]sok.Message{
        sok.Message{ .a = 0, .b = 0, .c = 1 },
        sok.Message{ .a = 0, .b = 0, .c = 2 },
        sok.Message{ .a = 0, .b = 1, .c = 0 },
        sok.Message{ .a = 0, .b = 1, .c = 12 },
        sok.Message{ .a = 4, .b = 10, .c = 2 },
    };
    for (messages) |msg| {
        const singleSlice = [1]sok.Message{msg};
        _ = client.send(std.mem.sliceAsBytes(&singleSlice)) catch try stdout.print("Failed to send ping bytes ...\n", .{});
    }
    _ = client.send("Ping!") catch try stdout.print("Failed to send ping bytes ...\n", .{});
    try bw.flush();
}
