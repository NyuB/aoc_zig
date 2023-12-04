const std = @import("std");
const lib = @import("tests_lib.zig");
const String = lib.String;

const uResult = u64;

fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uResult {
    var res: uResult = 0;
    for (lines.items) |line| {
        const numbers = lib.split_n_str(2, line, ": ")[1] orelse unreachable;
        const winning_available = lib.split_n_str(2, numbers, " | ");
        const winning = lib.split_str(allocator, winning_available[0] orelse unreachable, " ") catch unreachable;
        defer winning.deinit();
        const available = lib.split_str(allocator, winning_available[1] orelse unreachable, " ") catch unreachable;
        defer available.deinit();
        const matchCount = countMatchings(allocator, winning.items, available.items) catch unreachable;
        res += cardScore(matchCount);
    }
    return res;
}

fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uResult {
    var cardCount = CardCount.init(allocator, lines.items.len) catch unreachable;
    defer cardCount.deinit();
    for (lines.items, 0..lines.items.len) |line, i| {
        const numbers = lib.split_n_str(2, line, ": ")[1] orelse unreachable;
        const winning_available = lib.split_n_str(2, numbers, " | ");
        const winning = lib.split_str(allocator, winning_available[0] orelse unreachable, " ") catch unreachable;
        defer winning.deinit();
        const available = lib.split_str(allocator, winning_available[1] orelse unreachable, " ") catch unreachable;
        defer available.deinit();
        cardCount.countLine(allocator, i, winning.items, available.items) catch unreachable;
    }
    return cardCount.total;
}

const CardCount = struct {
    total: uResult,
    perCard: std.ArrayList(uResult),

    fn countLine(cardCount: *CardCount, allocator: std.mem.Allocator, lineIndex: usize, winning: []const String, available: []const String) !void {
        const thisCardCount = cardCount.perCard.items[lineIndex];
        cardCount.total += thisCardCount;
        const count = try countMatchings(allocator, winning, available);
        for (lineIndex + 1..lineIndex + 1 + count) |i| {
            cardCount.perCard.items[i] += thisCardCount;
        }
    }

    fn init(allocator: std.mem.Allocator, lineCount: usize) !CardCount {
        var perCard = try std.ArrayList(uResult).initCapacity(allocator, lineCount);
        for (0..lineCount) |_| {
            try perCard.append(1);
        }
        return CardCount{ .total = 0, .perCard = perCard };
    }

    fn deinit(self: *CardCount) void {
        self.perCard.deinit();
    }
};

fn cardScore(matchingCount: usize) uResult {
    if (matchingCount == 0) {
        return 0;
    } else {
        var res: uResult = 1;
        for (0..matchingCount - 1) |_| {
            res *= 2;
        }
        return res;
    }
}

fn countMatchings(allocator: std.mem.Allocator, winning: []const String, available: []const String) !usize {
    var set = try toWinningNumberSet(allocator, winning);
    defer set.deinit();
    var res: usize = 0;
    for (available) |a| {
        if (set.contains(a)) {
            res += 1;
        }
    }
    return res;
}

const unit = @TypeOf(.{});
const WinningNumberSet = std.StringHashMap(unit);
fn toWinningNumberSet(allocator: std.mem.Allocator, list: []const String) !WinningNumberSet {
    var res = WinningNumberSet.init(allocator);
    for (list) |i| {
        if (i.len > 0) { // filter out empty strings due to duplicated spaces
            try res.put(i, .{});
        }
    }
    return res;
}

test "Golden test part one" {
    const res = try lib.for_lines_allocating(uResult, std.testing.allocator, "problems/04.txt", solve_part_one);
    try std.testing.expectEqual(res, 19855);
}

test "Golden test part two" {
    const res = try lib.for_lines_allocating(uResult, std.testing.allocator, "problems/04.txt", solve_part_two);
    try std.testing.expectEqual(res, 10378710);
}

test "Example Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53");
    try lines.append("Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19");
    try lines.append("Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1");
    try lines.append("Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83");
    try lines.append("Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36");
    try lines.append("Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11");
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expect(res == 13);
}

test "Example Part Two" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53");
    try lines.append("Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19");
    try lines.append("Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1");
    try lines.append("Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83");
    try lines.append("Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36");
    try lines.append("Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11");
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expect(res == 30);
}

test "countMatching" {
    var winning = [_]String{ "1", "22", "333" };
    var available = [_]String{ "333", "7", "1" };
    const res = try countMatchings(std.testing.allocator, winning[0..], available[0..]);
    try std.testing.expect(res == 2);
}

test "Split on duplicated spaces" {
    const input = "1   22 333";
    const splitted = try lib.split_str(std.testing.allocator, input, " ");
    defer splitted.deinit();
    try std.testing.expectEqual(splitted.items.len, 5);
    try std.testing.expectEqualStrings(splitted.items[1], "");
    try std.testing.expectEqualStrings(splitted.items[2], "");
    try std.testing.expectEqualStrings(splitted.items[3], "22");
    try std.testing.expectEqualStrings(splitted.items[4], "333");
}
