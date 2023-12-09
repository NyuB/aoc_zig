const std = @import("std");
const sok = @import("sok.zig");
const os = std.os;

pub fn main() !void {

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const localAddress = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, 8888);
    const socket = try os.socket(localAddress.any.family, os.SOCK.DGRAM, 0);
    try os.bind(socket, &localAddress.any, @sizeOf(os.sockaddr.in));

    try stdout.print("UDPong listening on {d}!\n", .{localAddress.getPort()});
    try bw.flush(); // don't forget to flush!

    while (true) {
        var socketBuffer: [500]u8 = undefined;
        const expectedLen = @sizeOf(sok.Message);
        const receivedLen = try os.recv(socket, socketBuffer[0..expectedLen], 0);
        const received = socketBuffer[0..receivedLen];
        try stdout.print("UDPong received {d} bytes !\n", .{receivedLen});
        try bw.flush();
        if (std.mem.eql(u8, received, "Ping!")) {
            try stdout.print("\tReceived Ping, Ciao!\n", .{});
            try bw.flush();
            return;
        } else {
            const msg = std.mem.bytesAsSlice(sok.Message, received)[0];
            try stdout.print("\tReceived Message {d} {d} {d}\n", .{ msg.a, msg.b, msg.c });
            try bw.flush();
        }
    }
}
