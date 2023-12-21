const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u32;
const ProblemErrors = error{ AllocationFailed, IllegalState };

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    var graph = ModuleGraph.parse(allocator, lines.items) catch unreachable;
    defer graph.deinit();
    var highs: uint = 0;
    var lows: uint = 0;
    for (0..1000) |_| {
        var idleWatcher = ModuleGraph.MessageListener{};
        const res = graph.pulse(allocator, &idleWatcher) catch unreachable;
        highs += res[0];
        lows += res[1];
    }
    return highs * lows;
}

pub fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    var graph = ModuleGraph.parse(allocator, lines.items) catch unreachable;
    defer graph.deinit();
    if (graph.map.get("rx") == null) unreachable;
    var watcher = ModuleGraph.MessageListener{};
    var iter: uint = 0;
    while (watcher.rxCount < 1) {
        watcher = ModuleGraph.MessageListener{};
        _ = graph.pulse(allocator, &watcher) catch unreachable;
        iter += 1;
    }
    return iter;
}

const GateType = enum(u1) {
    FlipFlop = 0,
    Conj = 1,

    fn parse(c: u8) GateType {
        return if (c == '&') .Conj else .FlipFlop;
    }
};

const InputLevel = enum(u1) {
    Low = 0,
    High = 1,
};

const Message = struct {
    from: String,
    to: String,
    level: InputLevel,

    fn matchInput(m: Message, i: InputState) bool {
        return std.mem.eql(u8, m.from, i.id);
    }
};

const InputState = struct {
    id: String,
    level: InputLevel,
};

const Gate = struct {
    inputs: std.ArrayListUnmanaged(InputState),
    outputs: std.ArrayListUnmanaged(String),
    gateType: GateType,

    fn init(gateType: GateType) Gate {
        return .{ .inputs = std.ArrayListUnmanaged(InputState){}, .outputs = std.ArrayListUnmanaged(String){}, .gateType = gateType };
    }

    fn addInput(self: *Gate, allocator: std.mem.Allocator, id: String) ProblemErrors!void {
        self.inputs.append(allocator, InputState{ .id = id, .level = InputLevel.Low }) catch return ProblemErrors.AllocationFailed;
    }

    fn addOutput(self: *Gate, allocator: std.mem.Allocator, id: String) ProblemErrors!void {
        self.outputs.append(allocator, id) catch return ProblemErrors.AllocationFailed;
    }

    fn receive(self: *Gate, message: Message) ?InputLevel {
        return switch (self.gateType) {
            .Conj => self.conjReceive(message),
            .FlipFlop => self.flipFlopReceive(message),
        };
    }

    fn flipFlopReceive(self: *Gate, message: Message) ?InputLevel {
        if (message.level == InputLevel.High) return null;
        switch (self.inputs.items[0].level) {
            .High => {
                self.inputs.items[0].level = InputLevel.Low;
                return InputLevel.Low;
            },
            .Low => {
                self.inputs.items[0].level = InputLevel.High;
                return InputLevel.High;
            },
        }
    }

    fn conjReceive(self: *Gate, message: Message) ?InputLevel {
        for (self.inputs.items) |*input| {
            if (message.matchInput(input.*)) {
                input.level = message.level;
                break;
            }
        }
        for (self.inputs.items) |input| {
            if (input.level == InputLevel.Low) {
                return InputLevel.High;
            }
        }
        return InputLevel.Low;
    }
};

const GateMap = std.StringHashMapUnmanaged(Gate);
const ModuleGraph = struct {
    map: GateMap,
    arena: std.heap.ArenaAllocator,

    fn addLink(self: *ModuleGraph, origin: String, originType: GateType, target: String) ProblemErrors!void {
        if (self.map.getPtr(origin)) |originGate| {
            try originGate.*.addOutput(self.arena.allocator(), target);
            originGate.*.gateType = originType;
        } else {
            var originGate = Gate.init(originType);
            try originGate.addOutput(self.arena.allocator(), target);
            self.map.put(self.arena.allocator(), origin, originGate) catch return ProblemErrors.AllocationFailed;
        }
        if (self.map.getPtr(target)) |targetGate| {
            try targetGate.*.addInput(self.arena.allocator(), origin);
        } else {
            var targetGate = Gate.init(GateType.FlipFlop);
            try targetGate.addInput(self.arena.allocator(), origin);
            self.map.put(self.arena.allocator(), target, targetGate) catch return ProblemErrors.AllocationFailed;
        }
    }

    fn parse(allocator: std.mem.Allocator, lines: []const String) ProblemErrors!ModuleGraph {
        var res = ModuleGraph.init(allocator);
        for (lines) |l| {
            const originTargets = lib.split_n_str(2, l, " -> ");
            const origin = originTargets[0] orelse unreachable;
            const originType = GateType.parse(origin[0]);
            const originId = if (origin[0] == 'b') origin else origin[1..];
            var targets = lib.split_str(allocator, originTargets[1] orelse unreachable, ", ") catch return ProblemErrors.AllocationFailed;
            defer targets.deinit();
            for (targets.items) |t| {
                try res.addLink(originId, originType, t);
            }
        }
        return res;
    }

    fn init(allocator: std.mem.Allocator) ModuleGraph {
        var map = GateMap{};
        var arena = std.heap.ArenaAllocator.init(allocator);
        return .{ .map = map, .arena = arena };
    }

    fn deinit(self: *ModuleGraph) void {
        self.arena.deinit();
    }

    fn pulse(self: *ModuleGraph, allocator: std.mem.Allocator, watcher: *MessageListener) ProblemErrors![2]uint {
        var q = std.fifo.LinearFifo(Message, std.fifo.LinearFifoBufferType.Dynamic).init(allocator);
        defer q.deinit();
        var lows: uint = 1; // Initial low from button to brodacaster
        var highs: uint = 0;
        var broadcaster = self.map.get("broadcaster") orelse unreachable;
        for (broadcaster.outputs.items) |gateId| {
            q.writeItem(Message{ .from = "broadcaster", .to = gateId, .level = InputLevel.Low }) catch return ProblemErrors.AllocationFailed;
        }
        // std.debug.print("Starting loop\n", .{});
        while (q.readItem()) |msg| {
            watcher.notify(msg);
            // std.debug.print("{s} -{s}-> {s}\n", .{ msg.from, if (msg.level == InputLevel.Low) "-low" else "high", msg.to });
            switch (msg.level) {
                .High => highs += 1,
                .Low => lows += 1,
            }
            var gate = self.map.get(msg.to) orelse unreachable;
            if (gate.receive(msg)) |level| {
                for (gate.outputs.items) |target| {
                    q.writeItem(Message{ .from = msg.to, .to = target, .level = level }) catch return ProblemErrors.AllocationFailed;
                }
            }
        }
        return [2]uint{ lows, highs };
    }

    const MessageListener = struct {
        rxCount: uint = 0,

        fn notify(self: *MessageListener, msg: Message) void {
            if (msg.level == InputLevel.Low and std.mem.eql(u8, msg.to, "rx")) {
                self.rxCount += 1;
            }
        }
    };
};

// Tests

test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/20.txt", solve_part_one);
    try std.testing.expectEqual(@as(uint, 806332748), res);
}

// test "Golden Test Part Two" {
//     const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/20.txt", solve_part_two);
//     try std.testing.expectEqual(@as(uint, 0), res);
// }

test "Example Part One (1)" {
    // TODO Test solve_part_one on the problem example here
    var lines = std.ArrayList(String).init(std.testing.allocator);
    try lines.append("broadcaster -> a, b, c");
    try lines.append("%a -> b");
    try lines.append("%b -> c");
    try lines.append("%c -> inv");
    try lines.append("&inv -> a");
    defer lines.deinit();
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 32000000), res);
}

test "Example Part One (2)" {
    // TODO Test solve_part_one on the problem example here
    var lines = std.ArrayList(String).init(std.testing.allocator);
    try lines.append("broadcaster -> a");
    try lines.append("%a -> inv, con");
    try lines.append("&inv -> b");
    try lines.append("%b -> con");
    try lines.append("&con -> output");
    defer lines.deinit();
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 11687500), res);
}
