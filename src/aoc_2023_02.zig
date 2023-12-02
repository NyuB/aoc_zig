const std = @import("std");
const lib = @import("tests_lib.zig");
const String = lib.String;

pub fn solve_part_one(lines: std.ArrayList(String)) i32 {
    const allocator = std.heap.page_allocator;
    const available = Draw.rgb(12, 13, 14);
    var res: i32 = 0;
    for (lines.items) |line| {
        const g = Game.parse(allocator, line) catch unreachable;
        if (g.possible_given_available(available)) {
            res += g.id;
        }
    }
    return res;
}

pub fn solve_part_two(lines: std.ArrayList(String)) i32 {
    const allocator = std.heap.page_allocator;
    var res: i32 = 0;
    for (lines.items) |line| {
        const g = Game.parse(allocator, line) catch unreachable;
        const required = g.minimal_draw_required();
        res += required.power();
    }
    return res;
}

const Draw = struct {
    red: i32,
    green: i32,
    blue: i32,

    pub fn rgb(red: i32, green: i32, blue: i32) Draw {
        return Draw{ .red = red, .green = green, .blue = blue };
    }

    pub fn parse(allocator: std.mem.Allocator, s: String) Draw {
        const nb_colors = lib.split_str_exn(allocator, s, ", ");
        defer nb_colors.deinit();
        var red: i32 = 0;
        var green: i32 = 0;
        var blue: i32 = 0;
        for (nb_colors.items) |nb_color| {
            const n_c = lib.split_str_exn(allocator, nb_color, " ");
            defer n_c.deinit();
            const count = lib.int_of_string_exn(n_c.items[0]);
            const color = n_c.items[1];
            if (lib.starts_with("red", color)) {
                red = count;
            }
            if (lib.starts_with("green", color)) {
                green = count;
            }
            if (lib.starts_with("blue", color)) {
                blue = count;
            }
        }
        return rgb(red, green, blue);
    }

    pub fn merge_max(da: Draw, db: Draw) Draw {
        const r = if (da.red > db.red) da.red else db.red;
        const g = if (da.green > db.green) da.green else db.green;
        const b = if (da.blue > db.blue) da.blue else db.blue;
        return Draw.rgb(r, g, b);
    }

    pub fn power(d: Draw) i32 {
        return d.red * d.green * d.blue;
    }

    pub fn possible_given_available(attempt: Draw, available: Draw) bool {
        return attempt.red <= available.red and attempt.green <= available.green and attempt.blue <= available.blue;
    }
};

const Game = struct {
    id: i32,
    draws: std.ArrayList(Draw),

    const Self = @This();

    pub fn parse(allocator: std.mem.Allocator, s: String) !Game {
        const game_draws = lib.split_str_exn(allocator, s, ": ");
        defer game_draws.deinit();

        const g_id = lib.split_str_exn(allocator, game_draws.items[0], " ");
        defer g_id.deinit();

        const draws_str = lib.split_str_exn(allocator, game_draws.items[1], "; ");
        defer draws_str.deinit();

        var draws = std.ArrayList(Draw).init(allocator);
        for (draws_str.items) |ds| {
            try draws.append(Draw.parse(allocator, ds));
        }

        const id = lib.int_of_string_exn(g_id.items[1]);
        return Game{ .id = id, .draws = draws };
    }

    pub fn deinit(self: Self) void {
        self.draws.deinit();
    }

    pub fn minimal_draw_required(g: Game) Draw {
        var res = Draw.rgb(0, 0, 0);
        for (g.draws.items) |d| {
            res = res.merge_max(d);
        }
        return res;
    }

    pub fn possible_given_available(attempt: Game, available: Draw) bool {
        for (attempt.draws.items) |d| {
            if (!d.possible_given_available(available)) {
                return false;
            }
        }
        return true;
    }
};

test "Golden Test Part One" {
    const res = try lib.for_lines(i32, "problems/02.txt", solve_part_one);
    try std.testing.expectEqual(@as(i32, 2505), res);
}

test "Golden Test Part Two" {
    const res = try lib.for_lines(i32, "problems/02.txt", solve_part_two);
    try std.testing.expectEqual(@as(i32, 70265), res);
}

test "Draw.Parse" {
    try std.testing.expectEqual(Draw{ .red = 3, .green = 0, .blue = 0 }, Draw.parse(std.testing.allocator, "3 red"));
    try std.testing.expectEqual(Draw{ .red = 3, .green = 2, .blue = 0 }, Draw.parse(std.testing.allocator, "3 red, 2 green"));
    try std.testing.expectEqual(Draw{ .red = 3, .green = 2, .blue = 4 }, Draw.parse(std.testing.allocator, "3 red, 2 green, 4 blue"));
    try std.testing.expectEqual(Draw{ .red = 3, .green = 0, .blue = 4 }, Draw.parse(std.testing.allocator, "3 red, 4 blue"));
    try std.testing.expectEqual(Draw{ .red = 4, .green = 3, .blue = 0 }, Draw.parse(std.testing.allocator, "3 green, 4 red"));
}

test "Game.Parse" {
    const input = "Game 8: 8 blue, 1 red, 11 green; 11 blue, 10 red, 7 green; 4 blue, 6 green, 4 red; 3 blue, 2 green, 6 red; 4 green, 4 red, 1 blue; 5 blue, 12 red, 9 green";
    const game = try Game.parse(std.testing.allocator, input);
    defer game.deinit();
    try std.testing.expectEqual(@as(i32, 8), game.id);
    try std.testing.expectEqual(@as(usize, 6), game.draws.items.len);
    try std.testing.expectEqual(Draw{ .blue = 8, .red = 1, .green = 11 }, game.draws.items[0]);
    try std.testing.expectEqual(Draw{ .blue = 11, .red = 10, .green = 7 }, game.draws.items[1]);
    try std.testing.expectEqual(Draw{ .blue = 4, .green = 6, .red = 4 }, game.draws.items[2]);
    try std.testing.expectEqual(Draw{ .blue = 3, .green = 2, .red = 6 }, game.draws.items[3]);
    try std.testing.expectEqual(Draw{ .green = 4, .red = 4, .blue = 1 }, game.draws.items[4]);
    try std.testing.expectEqual(Draw{ .blue = 5, .red = 12, .green = 9 }, game.draws.items[5]);
}
