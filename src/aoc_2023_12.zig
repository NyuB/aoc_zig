const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u32;
const ProblemErrors = error{AllocationFailed};

fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    var res: uint = 0;
    for (lines.items) |l| {
        const lineGroups = lib.split_n_str(2, l, " ");
        const line = lineGroups[0] orelse unreachable;
        const groupsStr = lib.split_str(allocator, lineGroups[1] orelse unreachable, ",") catch unreachable;
        defer groupsStr.deinit();
        const groups = allocator.alloc(usize, groupsStr.items.len) catch unreachable;
        defer allocator.free(groups);
        for (groupsStr.items, 0..) |gStr, i| {
            const g = lib.num_of_string_exn(usize, gStr);
            groups[i] = g;
        }
        const search = SearchItem.make(groups, line, 0);
        res += search.countArrangements(allocator) catch unreachable;
    }
    return res;
}

const SearchItem = struct {
    groups: []const usize,
    line: []const u8,
    start: usize,

    inline fn make(groups: []const usize, line: []const u8, start: usize) SearchItem {
        return SearchItem{ .groups = groups, .line = line, .start = start };
    }

    fn copyMatching(self: SearchItem, from: usize, n: usize) SearchItem {
        return make(self.groups[1..], self.line, from + n + 1);
    }

    fn copySkipping(self: SearchItem, index: usize) SearchItem {
        return make(self.groups, self.line, index + 1);
    }

    fn countArrangements(self: SearchItem, allocator: std.mem.Allocator) ProblemErrors!uint {
        var q = std.ArrayList(SearchItem).init(allocator);
        defer q.deinit();
        q.append(self) catch return ProblemErrors.AllocationFailed;
        var res: uint = 0;
        while (q.popOrNull()) |*item| {
            if (item.over()) {
                res += 1;
            } else if (item.groups.len > 0) {
                var nextItems = try item.next(allocator);
                defer nextItems.deinit();
                q.appendSlice(nextItems.items) catch return ProblemErrors.AllocationFailed;
            }
        }
        return res;
    }

    fn next(self: SearchItem, allocator: std.mem.Allocator) ProblemErrors!std.ArrayList(SearchItem) {
        var res = std.ArrayList(SearchItem).init(allocator);
        errdefer res.deinit();
        var index = self.start;
        const n = self.groups[0];
        while (index + n <= self.line.len) {
            if (self.match(index, n)) {
                const matching = self.copyMatching(index, n);
                res.append(matching) catch return ProblemErrors.AllocationFailed;
                if (self.line[index] == '?') {
                    const skip = self.copySkipping(index);
                    res.append(skip) catch return ProblemErrors.AllocationFailed;
                }
                return res;
            } else if (self.line[index] == '#') {
                // No match but #, impossible
                return res;
            }
            index += 1;
        }
        return res;
    }

    fn match(self: SearchItem, index: usize, n: usize) bool {
        for (index..index + n) |i| {
            if (self.line[i] == '.') {
                return false;
            }
        }
        return index + n == self.line.len or self.line[index + n] != '#';
    }

    fn over(self: SearchItem) bool {
        if (self.groups.len > 0) return false;
        if (self.start >= self.line.len) return true;
        for (self.start..self.line.len) |i| {
            if (self.line[i] == '#') return false;
        }
        return true;
    }
};

// Tests

test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/12.txt", solve_part_one);
    try std.testing.expectEqual(@as(uint, 7716), res);
}

test "Example Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("???.### 1,1,3");
    try lines.append(".??..??...?##. 1,1,3");
    try lines.append("?#?#?#?#?#?#?#? 1,3,1,6");
    try lines.append("????.#...#... 4,1,1");
    try lines.append("????.######..#####. 1,6,5");
    try lines.append("?###???????? 3,2,1");
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 21), res);
}

test "???.### 1,1,3 => 1" {
    try expectArrangementEquals("???.### 1,1,3", 1);
    try expectArrangementEquals("###.??? 3,1,1", 1);
}

test ".??..??...?##. 1,1,3 => 4" {
    try expectArrangementEquals(".??..??...?##. 1,1,3", 4);
}

test "?#?#?#?#?#?#?#? 1,3,1,6 => 1" {
    try expectArrangementEquals("?#?#?#?#?#?#?#? 1,3,1,6", 1);
}

test "????.#...#... 4,1,1 => 1" {
    try expectArrangementEquals("????.#...#... 4,1,1", 1);
}

test "????.######..#####. 1,6,5 => 4" {
    try expectArrangementEquals("????.######..#####. 1,6,5", 4);
}

test "?###???????? 3,2,1 => 10" {
    try expectArrangementEquals("?###???????? 3,2,1", 10);
}

test "One group 3/4" {
    try expectArrangementEquals("???? 3", 2);
}

test "One group trailing #" {
    try expectArrangementEquals("???# 3", 1);
}

test "One group leading #" {
    try expectArrangementEquals("#??? 3", 1);
}

test "Impossible" {
    const impossibles = [_]String{
        " 1",
        "# 2",
        "#. 2",
        ".# 2",
        "?. 2",
        "??.### 3,2",
        "???## 3,2",
    };
    for (impossibles) |i| {
        try expectArrangementEquals(i, 0);
    }
}

test "Various cases" {
    const TestCase = struct { input: String, expected: uint };
    const cases = [_]TestCase{
        .{ .input = "##??.??#???. 4,5", .expected = 2 },
        .{ .input = "???????????.??##?. 1,6,1,1,3", .expected = 4 },
    };
    for (cases) |case| {
        try expectArrangementEquals(case.input, case.expected);
    }
}

fn expectArrangementEquals(line: String, expected: uint) !void {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append(line);
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(expected, res);
}
