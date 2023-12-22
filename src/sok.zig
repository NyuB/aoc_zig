const std = @import("std");
const os = std.os;

pub const UDPClient = struct {
    socket: os.socket_t,
    targetAddress: std.net.Address,

    pub const Errors = error{ SocketConnectionFailure, SendFailure };

    pub fn initIp4(addr: [4]u8, port: u16) Errors!UDPClient {
        const targetAddress = std.net.Address.initIp4(addr, port);
        const addrLen = @sizeOf(os.sockaddr.in);
        const socket = os.socket(targetAddress.any.family, os.SOCK.DGRAM, os.IPPROTO.UDP) catch return Errors.SocketConnectionFailure;
        os.connect(socket, &targetAddress.any, addrLen) catch {
            os.close(socket);
            return Errors.SocketConnectionFailure;
        };
        return UDPClient{ .socket = socket, .targetAddress = targetAddress };
    }

    pub fn send(self: UDPClient, bytes: []const u8) Errors!usize {
        return os.send(self.socket, bytes, 0) catch return Errors.SendFailure;
    }

    pub fn close(self: *UDPClient) void {
        os.close(self.socket);
    }
};

pub const Message = packed struct { a: u8, b: u24, c: u31 };

test "Single ping" {
    var serverContext = TestContext{};

    var serverThread = try std.Thread.spawn(.{}, testLoop, .{&serverContext});

    var client = try UDPClient.initIp4(.{ 127, 0, 0, 1 }, 8888);
    defer client.close();

    const sent = try client.send("Ping!");
    serverThread.join();
    try std.testing.expect(sent == 5);
    try std.testing.expect(serverContext.messageCount == 0);
}

test "Two messages then ping" {
    var serverContext = TestContext{};

    var serverThread = try std.Thread.spawn(.{}, testLoop, .{&serverContext});

    var client = try UDPClient.initIp4(.{ 127, 0, 0, 1 }, 8888);
    defer client.close();

    const messages = [2]Message{
        Message{ .a = 0, .b = 0, .c = 1 },
        Message{ .a = 4, .b = 10, .c = 2 },
    };

    var sent = try client.send(std.mem.sliceAsBytes(messages[0..1]));
    sent = try client.send(std.mem.sliceAsBytes(messages[1..2]));
    sent = try client.send("Ping!");
    try std.testing.expect(sent == 5);
    serverThread.join();
    try std.testing.expect(serverContext.messageCount == 2);
    try std.testing.expect(serverContext.aSum == 4);
    try std.testing.expect(serverContext.bSum == 10);
    try std.testing.expect(serverContext.cSum == 3);
}

const TestContext = struct {
    messageCount: usize = 0,
    aSum: u32 = 0,
    bSum: u32 = 0,
    cSum: u32 = 0,
};

fn testLoop(context: anytype) !void {
    const localAddress = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, 8888);
    const socket = try os.socket(localAddress.any.family, os.SOCK.DGRAM, 0);
    try os.bind(socket, &localAddress.any, @sizeOf(os.sockaddr.in));
    defer os.closeSocket(socket);

    while (true) {
        var socketBuffer: [500]u8 = undefined;
        const expectedLen = @sizeOf(Message);
        const receivedLen = try os.recv(socket, socketBuffer[0..expectedLen], 0);
        const received = socketBuffer[0..receivedLen];
        if (std.mem.eql(u8, received, "Ping!")) {
            return;
        } else {
            const msg = std.mem.bytesAsSlice(Message, received)[0];
            context.messageCount += 1;
            context.aSum += @as(u32, msg.a);
            context.bSum += @as(u32, msg.b);
            context.cSum += @as(u32, msg.c);
        }
    }
}
