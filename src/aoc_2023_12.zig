const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;
const uint = u64;
const ProblemErrors = error{AllocationFailed};

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
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
        const search = SearchItem.make(groups, line);
        res += search.countArrangements() orelse 0;
    }
    return res;
}

pub fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    var res: uint = 0;
    for (lines.items) |l| {
        const lineGroups = lib.split_n_str(2, l, " ");

        const line = lineGroups[0] orelse unreachable;
        const duplicatedLine = duplicateLine(allocator, line, 5) catch unreachable;
        defer allocator.free(duplicatedLine);

        const groupsStr = lib.split_str(allocator, lineGroups[1] orelse unreachable, ",") catch unreachable;
        defer groupsStr.deinit();

        const groups = allocator.alloc(usize, groupsStr.items.len) catch unreachable;
        defer allocator.free(groups);
        for (groupsStr.items, 0..) |gStr, i| {
            const g = lib.num_of_string_exn(usize, gStr);
            groups[i] = g;
        }

        const duplicatedGroups = duplicateGroups(allocator, groups, 5) catch unreachable;
        defer allocator.free(duplicatedGroups);

        const search = SearchItem.make(duplicatedGroups, duplicatedLine);
        res += search.countArrangements() orelse 0;
    }
    return res;
}

const SearchItem = struct {
    groups: []const usize,
    line: []const u8,

    inline fn make(groups: []const usize, line: []const u8) SearchItem {
        return SearchItem{ .groups = groups, .line = line };
    }

    fn copyMatching(self: SearchItem, from: usize, n: usize) SearchItem {
        const nextLine = if (from + n >= self.line.len) self.line[from + n - 1 .. from + n - 1] else if (from + n + 1 >= self.line.len) self.line[from + n .. from + n] else self.line[from + n + 1 ..];
        return make(self.groups[1..], nextLine);
    }

    fn copySkipping(self: SearchItem, index: usize) SearchItem {
        const nextLine = if (index + 1 >= self.line.len) self.line[index..index] else self.line[index + 1 ..];
        return make(self.groups, nextLine);
    }

    fn countArrangements(self: SearchItem) ?uint {
        if (self.groups.len == 0) {
            return if (self.over()) 1 else null;
        }
        if (self.sumAvailable() < self.sumGroups()) return null;

        const gi = self.maxGroupIndex();
        const g = self.groups[gi];
        if (g > self.line.len) return null;
        var res: uint = 0;
        for (0..self.line.len - g + 1) |index| {
            if (self.match(index, g)) {
                const left = self.copyLeft(index, gi);
                const right = self.copyRight(index, gi);
                res += possibleProducts(left, right) orelse 0;
            }
        }
        return if (res > 0) res else null;
    }

    fn possibleProducts(left: SearchItem, right: SearchItem) ?uint {
        const first = if (left.groups.len < right.groups.len) left else right;
        const second = if (left.groups.len < right.groups.len) right else left;
        if (first.countArrangements()) |f| {
            if (second.countArrangements()) |s| {
                return f * s;
            }
        }
        return null;
    }

    fn copyLeft(self: SearchItem, index: usize, groupIndex: usize) SearchItem {
        const groups = self.groups[0..groupIndex];
        const line = if (index == 0) self.line[0..0] else self.line[0 .. index - 1];
        return SearchItem.make(groups, line);
    }

    fn copyRight(self: SearchItem, index: usize, groupIndex: usize) SearchItem {
        const g = self.groups[groupIndex];
        const groups = if (groupIndex == self.groups.len) self.groups[groupIndex..groupIndex] else self.groups[groupIndex + 1 ..];
        const nextIndex = index + g;
        const line = if (nextIndex == self.line.len) self.line[nextIndex - 1 .. nextIndex - 1] else if (nextIndex == self.line.len - 1) self.line[nextIndex..nextIndex] else self.line[nextIndex + 1 ..];
        return SearchItem.make(groups, line);
    }

    /// Select the biggest group to reduce search space as much as possible
    ///
    /// If all groups are of equal lengths, select the middle index to split search space
    fn maxGroupIndex(self: SearchItem) usize {
        var best = self.groups[0];
        var res: usize = 0;
        var foundBest = false;
        for (self.groups, 0..) |g, i| {
            if (g > best) {
                best = g;
                res = i;
                foundBest = true;
            }
        }
        return if (foundBest) res else (self.groups.len / 2);
    }

    fn sumGroups(self: SearchItem) uint {
        var res: uint = 0;
        for (self.groups) |g| {
            res += @intCast(g);
        }
        return res;
    }

    fn sumAvailable(self: SearchItem) uint {
        var res: uint = 0;
        for (self.line) |c| {
            if (c != '.') {
                res += 1;
            }
        }
        return res;
    }

    fn next(self: SearchItem, allocator: std.mem.Allocator) ProblemErrors!std.ArrayList(SearchItem) {
        var res = std.ArrayList(SearchItem).init(allocator);
        errdefer res.deinit();
        var index: usize = 0;
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
        if (index != 0 and self.line[index - 1] == '#') return false;

        for (index..index + n) |i| {
            if (self.line[i] == '.') {
                return false;
            }
        }

        return index + n == self.line.len or self.line[index + n] != '#';
    }

    fn over(self: SearchItem) bool {
        if (self.groups.len > 0) return false;
        for (self.line) |c| {
            if (c == '#') return false;
        }
        return true;
    }
};

fn duplicateLine(allocator: std.mem.Allocator, line: String, n: usize) ProblemErrors!String {
    const size = line.len * n + (n - 1);
    var res = allocator.alloc(u8, size) catch return ProblemErrors.AllocationFailed;
    for (line, 0..) |c, i| {
        res[i] = c;
    }
    var index = line.len;
    for (1..n) |i| {
        _ = i;
        res[index] = '?';
        index += 1;
        for (line) |c| {
            res[index] = c;
            index += 1;
        }
    }
    return res;
}

fn duplicateGroups(allocator: std.mem.Allocator, groups: []const usize, n: usize) ProblemErrors![]const usize {
    const size = groups.len * n;
    var res = allocator.alloc(usize, size) catch return ProblemErrors.AllocationFailed;
    for (0..n) |i| {
        for (groups, 0..) |g, j| {
            res[i * groups.len + j] = g;
        }
    }
    return res;
}

// Tests

test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/12.txt", solve_part_one);
    try std.testing.expectEqual(@as(uint, 7716), res);
}

test "Golden Test Part Two" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/12.txt", solve_part_two);
    try std.testing.expectEqual(@as(uint, 18716325559999), res);
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

test "Example Part Two" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("???.### 1,1,3");
    try lines.append(".??..??...?##. 1,1,3");
    try lines.append("?#?#?#?#?#?#?#? 1,3,1,6");
    try lines.append("????.#...#... 4,1,1");
    try lines.append("????.######..#####. 1,6,5");
    try lines.append("?###???????? 3,2,1");
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 525152), res);
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

test "Duplicate line" {
    const input = "##.";
    var res = try duplicateLine(std.testing.allocator, input, 2);
    defer std.testing.allocator.free(res);
    try std.testing.expectEqualStrings("##.?##.", res);
}

test "Duplicate groups" {
    const input = [_]usize{ 1, 2, 3 };
    var res = try duplicateGroups(std.testing.allocator, &input, 2);
    defer std.testing.allocator.free(res);
    try std.testing.expectEqualSlices(usize, &[_]usize{ 1, 2, 3, 1, 2, 3 }, res);
}

test "SearchItem.copyLeft" {
    const groups = [_]usize{ 0, 1, 2 };
    const line = "?#.";
    const item = SearchItem.make(&groups, line);

    const left = item.copyLeft(0, 0);
    try std.testing.expectEqualSlices(usize, &[_]usize{}, left.groups);
    try std.testing.expectEqualSlices(u8, "", left.line);

    const center = item.copyLeft(1, 1);
    try std.testing.expectEqualSlices(usize, &[_]usize{0}, center.groups);
    try std.testing.expectEqualSlices(u8, "", center.line);

    const centerLeft = item.copyLeft(0, 1);
    try std.testing.expectEqualSlices(usize, &[_]usize{0}, centerLeft.groups);
    try std.testing.expectEqualSlices(u8, "", centerLeft.line);

    const centerRight = item.copyLeft(2, 1);
    try std.testing.expectEqualSlices(usize, &[_]usize{0}, centerRight.groups);
    try std.testing.expectEqualSlices(u8, "?", centerRight.line);
}

test "SearchItem.copyRight" {
    const groups = [_]usize{ 0, 1, 2 };
    const line = "0123456789";
    const item = SearchItem.make(&groups, line);

    const last = item.copyRight(9, 0);
    try std.testing.expectEqualSlices(usize, &[_]usize{ 1, 2 }, last.groups);
    try std.testing.expectEqualSlices(u8, "", last.line);

    const six = item.copyRight(6, 2);
    try std.testing.expectEqualSlices(usize, &[_]usize{}, six.groups);
    try std.testing.expectEqualSlices(u8, "9", six.line);
}

fn expectArrangementEquals(line: String, expected: uint) !void {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append(line);
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(expected, res);
}
