const std = @import("std");
const expect = std.testing.expect;
const lib = @import("tests_lib.zig");
const String = lib.String;

const uint = u64;

const Card = u4;
const JACK: Card = 11;
const QUEEN: Card = 12;
const KING: Card = 13;
const ACE: Card = 14;

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    return solve(allocator, lines, CamelPoker.handLessThan);
}

pub fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uint {
    return solve(allocator, lines, CamelJoker.handLessThan);
}

fn solve(allocator: std.mem.Allocator, lines: std.ArrayList(String), comptime Rules: fn (Hand, Hand) bool) uint {
    var bids = Bid.parseList(allocator, lines.items) catch unreachable;
    defer bids.deinit();
    Bid.sort(bids.items, Rules);
    var res: uint = 0;
    for (bids.items, 0..) |bid, rank| {
        res += (bid.value * (rank + 1));
    }
    return res;
}

const Hand = struct {
    cards: [5]Card,
    fn make(cards: [5]Card) Hand {
        return Hand{ .cards = cards };
    }

    fn count(self: Hand, card: Card) u4 {
        var res: u4 = 0;
        for (self.cards) |c| {
            if (c == card) {
                res += 1;
            }
        }
        return res;
    }

    fn replaced(self: Hand, i: usize, c: Card) Hand {
        var copy: [5]Card = undefined;
        @memcpy(&copy, &self.cards);
        copy[i] = c;
        return Hand.make(copy);
    }
};

fn figureReplacingJokerRec(hand: Hand, index: usize, F: *const fn (Hand) bool) bool {
    if (index == 5) {
        return F(hand);
    }
    if (hand.cards[index] != JACK) {
        return figureReplacingJokerRec(hand, index + 1, F);
    }

    const replacement = [_]Card{ 2, 3, 4, 5, 6, 7, 8, 9, 10, QUEEN, KING, ACE }; // no JACK
    for (replacement) |card| {
        const replaced = hand.replaced(index, card);
        if (figureReplacingJokerRec(replaced, index + 1, F)) {
            return true;
        }
    }
    return false;
}

fn isFigureWhenJokerAllowed(hand: Hand, F: *const fn (Hand) bool) bool {
    return figureReplacingJokerRec(hand, 0, F);
}

fn fiveOfAKind(hand: Hand) bool {
    const unique = hand.cards[0];
    for (hand.cards) |card| {
        if (card != unique) {
            return false;
        }
    }
    return true;
}

fn fourOfAKind(hand: Hand) bool {
    for (hand.cards) |c| {
        if (hand.count(c) == 4) {
            return true;
        }
    }
    return false;
}

fn fullHouse(hand: Hand) bool {
    var two = false;
    var three = false;
    for (hand.cards) |c| {
        const n = hand.count(c);
        three = three or (n == 3);
        two = two or (n == 2);
    }
    return two and three;
}

fn threeOfAKind(hand: Hand) bool {
    var notTwo = true;
    var three = false;
    for (hand.cards) |c| {
        const n = hand.count(c);
        three = three or (n == 3);
        notTwo = notTwo and (n != 2);
    }
    return notTwo and three;
}

fn twoPairs(hand: Hand) bool {
    var first: ?u5 = null;
    for (hand.cards) |c| {
        if (hand.count(c) == 2) {
            if (first) |f| {
                if (f != c) {
                    return true;
                }
            } else {
                first = c;
            }
        }
    }
    return false;
}

fn singlePair(hand: Hand) bool {
    var uniquePair: ?u4 = null;
    for (hand.cards) |c| {
        const n = hand.count(c);
        if (n > 2) {
            return false;
        }
        if (n == 2) {
            if (uniquePair) |f| {
                if (c != f) {
                    return false;
                }
            } else {
                uniquePair = c;
            }
        }
    }
    return uniquePair != null;
}

const Figure = struct {
    isFigure: *const fn (hand: Hand) bool,
};

const orderedFigures = [_]Figure{
    Figure{ .isFigure = fiveOfAKind },
    Figure{ .isFigure = fourOfAKind },
    Figure{ .isFigure = fullHouse },
    Figure{ .isFigure = threeOfAKind },
    Figure{ .isFigure = twoPairs },
    Figure{ .isFigure = singlePair },
};

const CamelPoker = struct {
    fn handLessThan(a: Hand, b: Hand) bool {
        for (orderedFigures) |f| {
            const fa = f.isFigure(a);
            const fb = f.isFigure(b);
            if (fa and !fb) {
                return false;
            }
            if (fb and !fa) {
                return true;
            }
            if (fa and fb) {
                break;
            }
        }
        return lessThanCardToCard(a, b);
    }

    fn lessThanCardToCard(a: Hand, b: Hand) bool {
        for (a.cards, 0..) |ca, i| {
            if (ca < b.cards[i]) {
                return true;
            } else if (ca > b.cards[i]) {
                return false;
            }
        }
        return false;
    }
};

const CamelJoker = struct {
    fn handLessThan(a: Hand, b: Hand) bool {
        for (orderedFigures) |f| {
            const fa = isFigureWhenJokerAllowed(a, f.isFigure);
            const fb = isFigureWhenJokerAllowed(b, f.isFigure);
            if (fa and !fb) {
                return false;
            }
            if (fb and !fa) {
                return true;
            }
            if (fa and fb) {
                break;
            }
        }
        return lessThanCardToCard(a, b);
    }

    fn lessThanCardToCard(a: Hand, b: Hand) bool {
        for (a.cards, 0..) |ca, i| {
            const cb = b.cards[i];
            if (ca == cb) continue;
            if (ca == JACK) {
                return true;
            } else if (cb == JACK) {
                return false;
            } else if (ca < cb) {
                return true;
            } else if (cb < ca) {
                return false;
            }
        }
        return false;
    }
};

const Bid = struct {
    value: uint,
    hand: Hand,

    fn sort(bids: []Bid, Rules: *const fn (Hand, Hand) bool) void {
        std.sort.pdq(Bid, bids, Rules, Bid.lessThan);
    }

    fn lessThan(Rules: *const fn (Hand, Hand) bool, self: Bid, other: Bid) bool {
        return Rules(self.hand, other.hand);
    }

    fn parse(line: String) Bid {
        const split = lib.split_n_str(2, line, " ");
        const bid = lib.num_of_string_exn(uint, split[1] orelse unreachable);
        var cards: [5]Card = undefined;
        const cardStr = split[0] orelse unreachable;
        for (cardStr, 0..) |c, i| {
            const card: Card = switch (c) {
                '2' => 2,
                '3' => 3,
                '4' => 4,
                '5' => 5,
                '6' => 6,
                '7' => 7,
                '8' => 8,
                '9' => 9,
                'T' => 10,
                'J' => JACK,
                'Q' => QUEEN,
                'K' => KING,
                'A' => ACE,
                else => unreachable,
            };
            cards[i] = card;
        }

        return Bid{ .value = bid, .hand = Hand.make(cards) };
    }

    fn parseList(allocator: std.mem.Allocator, lines: []String) !std.ArrayList(Bid) {
        var res = std.ArrayList(Bid).init(allocator);
        for (lines) |l| {
            try res.append(Bid.parse(l));
        }
        return res;
    }
};

// Tests

test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/07.txt", solve_part_one);
    try std.testing.expectEqual(@as(uint, 248569531), res);
}

test "Golden Test Part Two" {
    const res = try lib.for_lines_allocating(uint, std.testing.allocator, "problems/07.txt", solve_part_two);
    try std.testing.expectEqual(@as(uint, 250382098), res);
}

test "Example Part One" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("32T3K 765");
    try lines.append("T55J5 684");
    try lines.append("KK677 28");
    try lines.append("KTJJT 220");
    try lines.append("QQQJA 483");
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 6440), res);
}

test "Example Part Two" {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    defer lines.deinit();
    try lines.append("32T3K 765");
    try lines.append("T55J5 684");
    try lines.append("KK677 28");
    try lines.append("KTJJT 220");
    try lines.append("QQQJA 483");
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uint, 5905), res);
}

test "Five of a kind" {
    const handOk = [_]Hand{
        Hand.make([_]Card{ 2, 2, 2, 2, 2 }),
        Hand.make([_]Card{ 3, 3, 3, 3, 3 }),
        Hand.make([_]Card{ 4, 4, 4, 4, 4 }),
        Hand.make([_]Card{ ACE, ACE, ACE, ACE, ACE }),
    };
    const handNotOk = [_]Hand{
        Hand.make([_]Card{ ACE, ACE, ACE, ACE, QUEEN }),
        Hand.make([_]Card{ JACK, 2, 2, 2, 2 }),
        Hand.make([_]Card{ 9, 9, KING, 9, 9 }),
        Hand.make([_]Card{ 2, 3, 4, 5, 6 }),
    };
    for (handOk) |ok| {
        try expect(fiveOfAKind(ok));
    }
    for (handNotOk) |ko| {
        try expect(!fiveOfAKind(ko));
    }
}

test "Four of a kind" {
    const handOk = [_]Hand{
        Hand.make([_]Card{ 2, 2, 2, 2, 1 }),
        Hand.make([_]Card{ 4, 3, 3, 3, 3 }),
        Hand.make([_]Card{ ACE, ACE, 10, ACE, ACE }),
    };
    const handNotOk = [_]Hand{
        Hand.make([_]Card{ ACE, ACE, ACE, ACE, ACE }),
        Hand.make([_]Card{ JACK, QUEEN, 2, 2, 2 }),
        Hand.make([_]Card{ 9, 9, KING, 2, 9 }),
        Hand.make([_]Card{ 2, 3, 4, 5, ACE }),
    };
    for (handOk) |ok| {
        try expect(fourOfAKind(ok));
    }
    for (handNotOk) |ko| {
        try expect(!fourOfAKind(ko));
    }
}

test "Full house" {
    const handOk = [_]Hand{
        Hand.make([_]Card{ ACE, ACE, ACE, 10, 10 }),
        Hand.make([_]Card{ 1, 2, 2, 2, 1 }),
        Hand.make([_]Card{ 4, 3, 4, 3, 3 }),
    };
    const handNotOk = [_]Hand{
        Hand.make([_]Card{ ACE, ACE, ACE, 10, 9 }),
        Hand.make([_]Card{ JACK, QUEEN, 2, 2, 1 }),
    };
    for (handOk) |ok| {
        try expect(fullHouse(ok));
    }
    for (handNotOk) |ko| {
        try expect(!fullHouse(ko));
    }
}

test "Three of a kind" {
    const handOk = [_]Hand{
        Hand.make([_]Card{ 2, 2, 2, 3, 1 }),
        Hand.make([_]Card{ 4, 3, 2, 2, 2 }),
        Hand.make([_]Card{ ACE, 9, 10, ACE, ACE }),
    };
    const handNotOk = [_]Hand{
        Hand.make([_]Card{ ACE, ACE, ACE, 10, 10 }), // Full house
        Hand.make([_]Card{ JACK, QUEEN, 2, 2, 1 }),
        Hand.make([_]Card{ 9, 9, KING, 2, 3 }),
        Hand.make([_]Card{ 2, 3, 4, 5, ACE }),
    };
    for (handOk) |ok| {
        try expect(threeOfAKind(ok));
    }
    for (handNotOk) |ko| {
        try expect(!threeOfAKind(ko));
    }
}

test "Two pairs" {
    const handOk = [_]Hand{
        Hand.make([_]Card{ 2, 2, 3, 3, 1 }),
        Hand.make([_]Card{ 4, 1, 2, 1, 2 }),
        Hand.make([_]Card{ ACE, KING, 10, KING, ACE }),
    };
    const handNotOk = [_]Hand{
        Hand.make([_]Card{ ACE, ACE, ACE, 10, 10 }),
        Hand.make([_]Card{ JACK, QUEEN, 2, 2, 1 }),
        Hand.make([_]Card{ 9, 9, KING, 2, 3 }),
        Hand.make([_]Card{ 2, 3, 4, 5, ACE }),
    };
    for (handOk) |ok| {
        try expect(twoPairs(ok));
    }
    for (handNotOk) |ko| {
        try expect(!twoPairs(ko));
    }
}

test "Single pair" {
    const handOk = [_]Hand{
        Hand.make([_]Card{ 2, 2, 3, 4, 5 }),
        Hand.make([_]Card{ 4, 1, 2, 1, 3 }),
        Hand.make([_]Card{ ACE, KING, 10, JACK, ACE }),
    };
    const handNotOk = [_]Hand{
        Hand.make([_]Card{ ACE, ACE, ACE, 10, 10 }),
        Hand.make([_]Card{ JACK, JACK, 2, 2, 1 }), // Two pairs
        Hand.make([_]Card{
            9,
            9,
            9,
            9,
            9,
        }),
        Hand.make([_]Card{ 2, 3, 4, 5, ACE }),
    };
    for (handOk) |ok| {
        try expect(singlePair(ok));
    }
    for (handNotOk) |ko| {
        try expect(!singlePair(ko));
    }
}

test "Full House < Four of a kind" {
    const fours = [_]Hand{
        Hand.make([_]Card{ 2, 2, 2, 2, 1 }),
        Hand.make([_]Card{ 4, 3, 3, 3, 3 }),
        Hand.make([_]Card{ ACE, ACE, 10, ACE, ACE }),
    };
    const fh = Hand.make([_]Card{ ACE, ACE, ACE, 10, 9 });
    for (fours) |winner| {
        try expect(CamelPoker.handLessThan(fh, winner));
    }
}

test "Fallback to card one to one" {
    const loser = Hand.make([_]Card{ 1, 2, 3, 5, 5 });
    const winner = Hand.make([_]Card{ 2, 1, 3, 4, 4 });
    try expect(CamelPoker.handLessThan(loser, winner));
    try expect(!CamelPoker.handLessThan(winner, loser));
}

test "Comparison from example" {
    const winner = Hand.make([_]Card{ QUEEN, QUEEN, QUEEN, JACK, ACE });
    const loser = Hand.make([_]Card{ 10, 5, 5, JACK, 5 });
    try expect(CamelPoker.handLessThan(loser, winner));
    try expect(!CamelPoker.handLessThan(winner, loser));
}

test "Becomes four of a kind using joker" {
    const original = Hand.make([_]Card{ QUEEN, JACK, JACK, QUEEN, 2 });
    try expect(!fourOfAKind(original));
    try expect(isFigureWhenJokerAllowed(original, fourOfAKind));
}

test "Joker becomes the weaker card" {
    const loser = Hand.make([_]Card{ JACK, KING, KING, KING, 2 });
    const winner = Hand.make([_]Card{ QUEEN, QUEEN, QUEEN, QUEEN, 2 });
    try expect(CamelJoker.handLessThan(loser, winner));
}
