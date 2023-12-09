const std = @import("std");
const os = std.os;

pub const Message = packed struct { a: u8, b: u24, c: u31 };

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
