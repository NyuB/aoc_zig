const std = @import("std");
const lib = @import("tests_lib.zig");
const String = lib.String;

/// Ah, the overflow problem again ...
const uResult = u64;
const maxResult: uResult = 1 << 64 - 1;

pub fn solve_part_one(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uResult {
    const seeds = lib.split_n_str(2, lines.items[0], "seeds: ")[1] orelse unreachable;
    var almanac = Almanac.parse(allocator, lines.items[2..]) catch unreachable;
    defer almanac.deinit();
    var res: ?uResult = null;
    var seedItems = lib.split_str(allocator, seeds, " ") catch unreachable;
    defer seedItems.deinit();
    for (seedItems.items) |s| {
        const seed = lib.num_of_string_exn(uResult, s);
        const location = almanac.convertFromSource("seed", seed, "location") orelse unreachable;
        if (res) |current| {
            res = @min(current, location);
        } else {
            res = location;
        }
    }
    return res orelse unreachable;
}

pub fn solve_part_two(allocator: std.mem.Allocator, lines: std.ArrayList(String)) uResult {
    const seeds = lib.split_n_str(2, lines.items[0], "seeds: ")[1] orelse unreachable;
    var almanac = Almanac.parse(allocator, lines.items[2..]) catch unreachable;
    defer almanac.deinit();
    var bestLocation: ?uResult = null;
    var seedItems = lib.split_str(allocator, seeds, " ") catch unreachable;
    defer seedItems.deinit();
    for (0..seedItems.items.len) |i| {
        if (i % 2 == 1) continue; // Only consider pairs
        const start = lib.num_of_string_exn(uResult, seedItems.items[i]);
        const range = lib.num_of_string_exn(uResult, seedItems.items[i + 1]);
        const span = Span.make(start, start + range - 1);

        // Find all location values reachable with this seed span
        const allDestinationSpans = (almanac.convertFromSourceSpan(allocator, "seed", span, "location") catch unreachable) orelse unreachable;
        defer allDestinationSpans.deinit();
        for (allDestinationSpans.items) |locationSpan| {
            // Update our current best with minimal value from the reachable spans
            if (bestLocation) |r| {
                bestLocation = @min(r, locationSpan.start);
            } else {
                bestLocation = locationSpan.start;
            }
        }
    }

    return bestLocation orelse unreachable;
}

/// Represents a mapping of value from a source space to a destination space as stated by the AOC problem
const MappingRange = struct {
    /// First value of the destination span coverd by this mapping
    destinationStart: uResult,
    /// First value of the source span covered by this mapping
    sourceStart: uResult,
    /// Number of value coverered
    range: uResult,

    fn convertSourceToDestination(self: MappingRange, source: uResult) ?uResult {
        if (source >= self.sourceStart and self.sourceStart + self.range > source) {
            return (source + self.destinationStart) - self.sourceStart;
        } else return null;
    }

    fn initSourceToDestination(s: uResult, d: uResult, r: uResult) MappingRange {
        return MappingRange{ .destinationStart = d, .sourceStart = s, .range = r };
    }

    fn identity(start: uResult, range: uResult) MappingRange {
        return initSourceToDestination(start, start, range);
    }

    /// Returns a the destination span corresponding to the part of `span` covered by this mapping source span
    ///
    /// **null** result means source span and `span` are fully disjoints
    fn mapSpan(self: MappingRange, span: Span) ?Span {
        var selfSpan = span.intersect(Span.make(self.sourceStart, self.sourceStart + self.range - 1));
        if (selfSpan) |s| {
            var start = self.convertSourceToDestination(s.start) orelse unreachable;
            var end = self.convertSourceToDestination(s.end) orelse unreachable;
            return Span.make(start, end);
        } else {
            return null;
        }
    }

    fn map(source: uResult, mappings: []MappingRange) uResult {
        for (mappings) |m| {
            if (m.convertSourceToDestination(source)) |v| {
                return v;
            }
        }
        // If no match, return as is
        return source;
    }

    /// The reversed mapping, mapping destination to source
    fn reversed(self: MappingRange) MappingRange {
        return initSourceToDestination(self.destinationStart, self.sourceStart, self.range);
    }

    fn parse(s: String) MappingRange {
        const trio = lib.split_n_str(3, s, " ");
        return initSourceToDestination(lib.num_of_string_exn(uResult, trio[1] orelse unreachable), lib.num_of_string_exn(uResult, trio[0] orelse unreachable), lib.num_of_string_exn(uResult, trio[2] orelse unreachable));
    }
};

const Almanac = struct {
    const AlmanacMap = std.StringHashMap(Conversion);
    /// /!\ **Read only** /!\
    map: AlmanacMap,

    fn deinit(self: *Almanac) void {
        var values = self.map.valueIterator();
        while (values.next()) |l| {
            l.deinit();
        }
        self.map.deinit();
    }

    /// Returns the conversion `sourceType` to `destinationType` from the initial value `sourceValue`
    /// A null result means no conversion path exists from `sourceType`to `destinationType`
    fn convertFromSource(self: Almanac, sourceType: String, sourceValue: uResult, destinationType: String) ?uResult {
        var currentType: String = sourceType;
        var current: uResult = sourceValue;
        while (!std.mem.eql(u8, currentType, destinationType)) {
            const conversion = self.getConversion(currentType) orelse return null;
            current = MappingRange.map(current, conversion.mappings.items);
            currentType = conversion.destination;
        }
        return current;
    }

    /// Returns all conversion values `sourceType` to `destinationType` from the initial values span `sourceSpan`
    /// Result is itself expressed as a list of **Span**s
    /// A null result means no conversion path exists from `sourceType`to `destinationType`
    fn convertFromSourceSpan(self: Almanac, allocator: std.mem.Allocator, sourceType: String, sourceSpan: Span, destinationType: String) !?std.ArrayList(Span) {
        var current = std.ArrayList(Span).init(allocator);
        try current.append(sourceSpan);
        var currentType = sourceType;
        while (!std.mem.eql(u8, currentType, destinationType)) {
            var next = std.ArrayList(Span).init(allocator);
            var conversion = self.getConversion(currentType) orelse {
                current.deinit();
                return null;
            };

            for (current.items) |span| {
                for (conversion.mappings.items) |mapping| {
                    const intersectOpt = mapping.mapSpan(span);
                    if (intersectOpt) |i| {
                        try next.append(i);
                    }
                }
            }

            currentType = conversion.destination;
            current.deinit();
            current = next;
        }
        return current;
    }

    fn parse(allocator: std.mem.Allocator, lines: []String) !Almanac {
        var map = AlmanacMap.init(allocator);
        var lineIndex: usize = 0;
        while (lineIndex < lines.len) {
            const header = lib.split_n_str(2, lines[lineIndex], " map:")[0] orelse unreachable;
            const sourceDestination = lib.split_n_str(2, header, "-to-");
            const source = sourceDestination[0] orelse unreachable;
            const destination = sourceDestination[1] orelse unreachable;
            var mappings = std.ArrayList(MappingRange).init(allocator);
            lineIndex += 1;
            while (lineIndex < lines.len and lines[lineIndex].len > 0) {
                const mapping = MappingRange.parse(lines[lineIndex]);
                try mappings.append(mapping);
                lineIndex += 1;
            }
            try map.put(source, try Conversion.init(destination, mappings));

            lineIndex += 1;
        }
        return Almanac{ .map = map };
    }

    /// The reversed almanac, converting from sink to source
    /// Could be used to find the exact seed leading to the problem solution ;)
    fn reversed(self: Almanac, allocator: std.mem.Allocator) !Almanac {
        var map = AlmanacMap.init(allocator);
        var entries = self.map.iterator();
        while (entries.next()) |entry| {
            const conversion = entry.value_ptr;
            const key = entry.key_ptr;
            var reversedMapping = std.ArrayList(MappingRange).init(allocator);

            for (conversion.mappings.items) |mapping| {
                try reversedMapping.append(mapping.reversed());
            }

            var reversedConversion = try Conversion.init(key.*, reversedMapping);
            try map.put(conversion.destination, reversedConversion);
        }
        return Almanac{ .map = map };
    }

    // Internals

    fn getConversion(self: Almanac, source: String) ?Conversion {
        return self.map.get(source);
    }
};

const Conversion = struct {
    destination: String,
    /// /!\ **Read only** /!\
    mappings: std.ArrayList(MappingRange),

    /// Takes ownership of `mapping`
    fn init(destination: String, mappings: std.ArrayList(MappingRange)) !Conversion {
        var res = Conversion{ .mappings = mappings, .destination = destination };
        try res.completeMappings();
        return res;
    }

    fn deinit(self: Conversion) void {
        self.mappings.deinit();
    }

    // Internals

    /// Used to sort mapings by start value acending order
    fn lessThan(context: @TypeOf(.{}), lhs: MappingRange, rhs: MappingRange) bool {
        _ = context;
        return lhs.sourceStart < rhs.sourceStart;
    }

    /// Ensure mappings cover the entire positive i64 space
    fn completeMappings(self: *Conversion) !void {
        std.sort.pdq(MappingRange, self.mappings.items, .{}, lessThan);
        var nextMappings = std.ArrayList(MappingRange).init(self.mappings.allocator);
        var currentMin: uResult = 0;
        for (self.mappings.items) |mapping| {
            if (mapping.sourceStart > currentMin) {
                // Complete the missing interval with an identity mapping
                try nextMappings.append(MappingRange.identity(currentMin, mapping.sourceStart - currentMin));
            }
            try nextMappings.append(mapping);

            const nextMin = @addWithOverflow(mapping.sourceStart, mapping.range);
            currentMin = if (nextMin[1] != 0) maxResult else nextMin[0];
        }
        if (currentMin < maxResult) {
            var identityMapping = MappingRange.initSourceToDestination(currentMin, currentMin, maxResult - currentMin);
            try nextMappings.append(identityMapping);
        }
        self.mappings.deinit();
        self.mappings = nextMappings;
    }
};

/// A non-empty range of values
///
/// Use `Span.make(a,b)` to build safely
const Span = struct {
    start: uResult,
    end: uResult,

    /// Returns the values of `self` which are also values of `other`
    ///
    /// **null** result mean the two spans are fully disjoints
    fn intersect(self: Span, other: Span) ?Span {
        if (self.equals(other)) return self;
        if (self.start > other.end or other.start > self.end) return null;
        if (self.start == other.end) return Span.make(self.start, self.start);
        if (other.start == self.end) return Span.make(self.end, self.end);
        return Span.make(@max(self.start, other.start), @min(self.end, other.end));
    }

    /// Build a Span with start <= end (if `a > b`, `a` will become `end` and `b` will become `start`)
    fn make(a: uResult, b: uResult) Span {
        return Span{ .start = @min(a, b), .end = @max(a, b) };
    }

    // Internals

    fn equals(self: Span, other: Span) bool {
        return self.start == other.start and self.end == other.end;
    }
};

test "Golden Test Part One" {
    const res = try lib.for_lines_allocating(uResult, std.testing.allocator, "problems/05.txt", solve_part_one);
    try std.testing.expectEqual(@as(uResult, 910845529), res);
}

test "Golden Test Part Two" {
    const res = try lib.for_lines_allocating(uResult, std.testing.allocator, "problems/05.txt", solve_part_two);
    try std.testing.expectEqual(@as(uResult, 77435348), res);
}

test "Example Part One" {
    var lines = try example();
    defer lines.deinit();
    const res = solve_part_one(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uResult, 35), res);
}

test "Example Part Two" {
    var lines = try example();
    defer lines.deinit();
    const res = solve_part_two(std.testing.allocator, lines);
    try std.testing.expectEqual(@as(uResult, 46), res);
}

test "Almanac" {
    var lines = try example();
    defer lines.deinit();

    var almanac = try Almanac.parse(std.testing.allocator, lines.items[2..]);
    defer almanac.deinit();

    var reversed = try almanac.reversed(std.testing.allocator);
    defer reversed.deinit();

    try std.testing.expect(almanac.map.count() == 7);
    var seedToSoil = almanac.convertFromSource("seed", 98, "soil") orelse unreachable;
    var soilToSeed = reversed.convertFromSource("soil", 50, "seed") orelse unreachable;
    try std.testing.expectEqual(@as(uResult, 50), seedToSoil);
    try std.testing.expectEqual(@as(uResult, 98), soilToSeed);

    var convertedSpan = try almanac.convertFromSourceSpan(std.testing.allocator, "seed", Span.make(60, 63), "soil") orelse unreachable;
    defer convertedSpan.deinit();
    try std.testing.expectEqual(@as(usize, 1), convertedSpan.items.len);
    try std.testing.expectEqual(Span.make(62, 65), convertedSpan.items[0]);

    var overlappingSpan = try almanac.convertFromSourceSpan(std.testing.allocator, "water", Span.make(24, 25), "light") orelse unreachable;
    defer overlappingSpan.deinit();
    try std.testing.expectEqual(@as(usize, 2), overlappingSpan.items.len);
    try std.testing.expectEqual(Span.make(94, 94), overlappingSpan.items[0]);
    try std.testing.expectEqual(Span.make(18, 18), overlappingSpan.items[1]);
}

test "Mapping Range" {
    const range = MappingRange.initSourceToDestination(98, 50, 2);
    const inRangeStart = range.convertSourceToDestination(98);
    const inRangeEnd = range.convertSourceToDestination(99);
    const outRangeTooHigh = range.convertSourceToDestination(100);
    const outRangeTooLow = range.convertSourceToDestination(97);
    try std.testing.expectEqual(@as(?uResult, 50), inRangeStart);
    try std.testing.expectEqual(@as(?uResult, 51), inRangeEnd);
    try std.testing.expectEqual(@as(?uResult, null), outRangeTooLow);
    try std.testing.expectEqual(@as(?uResult, null), outRangeTooHigh);

    const spanInRange = Span.make(98, 99);
    const spanMapped = range.mapSpan(spanInRange) orelse unreachable;
    try std.testing.expectEqual(Span.make(50, 51), spanMapped);
}

test "Mapping spans two values in range" {
    const rangeTwoValues = MappingRange.initSourceToDestination(98, 50, 2);
    const spanInRange = Span.make(98, 99);
    const spanMapped = rangeTwoValues.mapSpan(spanInRange) orelse unreachable;
    try std.testing.expectEqual(Span.make(50, 51), spanMapped);
}

test "Mapping spans overlapping" {
    const rangeTwoValues = MappingRange.initSourceToDestination(10, 20, 11);
    const spanOverlapLeft = Span.make(5, 15);
    const spanOverlapRight = Span.make(15, 25);
    const spanLeftMapped = rangeTwoValues.mapSpan(spanOverlapLeft) orelse unreachable;
    const spanRightMapped = rangeTwoValues.mapSpan(spanOverlapRight) orelse unreachable;
    try std.testing.expectEqual(Span.make(20, 25), spanLeftMapped);
    try std.testing.expectEqual(Span.make(25, 30), spanRightMapped);
}

test "overlapping spans" {
    const left = Span.make(123, 456);
    const right = Span.make(234, 567);
    const intersectionLeftRight = left.intersect(right);
    const intersectionRightLeft = right.intersect(left);
    const expected: ?Span = Span{ .start = 234, .end = 456 };
    try std.testing.expectEqual(expected, intersectionLeftRight);
    try std.testing.expectEqual(expected, intersectionRightLeft);
}

test "span containing another" {
    const left = Span.make(234, 456);
    const right = Span.make(123, 567);
    const intersectionLeftRight = left.intersect(right);
    const intersectionRightLeft = right.intersect(left);
    try std.testing.expectEqual(@as(?Span, left), intersectionLeftRight);
    try std.testing.expectEqual(@as(?Span, left), intersectionRightLeft);
}

test "span not intersecting" {
    const left = Span.make(456, 567);
    const right = Span.make(123, 234);
    const intersectionLeftRight = left.intersect(right);
    const intersectionRightLeft = right.intersect(left);
    try std.testing.expectEqual(@as(?Span, null), intersectionLeftRight);
    try std.testing.expectEqual(@as(?Span, null), intersectionRightLeft);
}

test "Conversion at boundaries first span already covered" {
    const mappingCoveringMinResult = MappingRange.initSourceToDestination(0, 0, 1);
    var singleton = std.ArrayList(MappingRange).init(std.testing.allocator);
    try singleton.append(mappingCoveringMinResult);
    var conversion = try Conversion.init("whatever", singleton);
    defer conversion.deinit();
    try std.testing.expectEqual(@as(usize, 2), conversion.mappings.items.len);
    // initial mapping is preserved
    try std.testing.expectEqual(mappingCoveringMinResult, conversion.mappings.items[0]);
    // mappings completed with missing right span, as identity mapping
    try std.testing.expectEqual(MappingRange.initSourceToDestination(1, 1, maxResult - 1), conversion.mappings.items[1]);
}

test "Conversion at boundaries last span already covered" {
    const mappingCoveringMaxResult = MappingRange.initSourceToDestination(maxResult - 2, 0, 3);
    var singleton = std.ArrayList(MappingRange).init(std.testing.allocator);
    try singleton.append(mappingCoveringMaxResult);
    var conversion = try Conversion.init("whatever", singleton);
    defer conversion.deinit();
    try std.testing.expectEqual(@as(usize, 2), conversion.mappings.items.len);
    // mappings completed with missing left span, as identity mapping
    try std.testing.expectEqual(MappingRange.initSourceToDestination(0, 0, maxResult - 2), conversion.mappings.items[0]);
    // initial mapping is preserved
    try std.testing.expectEqual(mappingCoveringMaxResult, conversion.mappings.items[1]);
}

fn example() !std.ArrayList(String) {
    var lines = std.ArrayList(String).init(std.testing.allocator);
    try lines.append("seeds: 79 14 55 13");
    try lines.append("");
    try lines.append("seed-to-soil map:");
    try lines.append("50 98 2");
    try lines.append("52 50 48");
    try lines.append("");
    try lines.append("soil-to-fertilizer map:");
    try lines.append("0 15 37");
    try lines.append("37 52 2");
    try lines.append("39 0 15");
    try lines.append("");
    try lines.append("fertilizer-to-water map:");
    try lines.append("49 53 8");
    try lines.append("0 11 42");
    try lines.append("42 0 7");
    try lines.append("57 7 4");
    try lines.append("");
    try lines.append("water-to-light map:");
    try lines.append("88 18 7");
    try lines.append("18 25 70");
    try lines.append("");
    try lines.append("light-to-temperature map:");
    try lines.append("45 77 23");
    try lines.append("81 45 19");
    try lines.append("68 64 13");
    try lines.append("");
    try lines.append("temperature-to-humidity map:");
    try lines.append("0 69 1");
    try lines.append("1 0 69");
    try lines.append("");
    try lines.append("humidity-to-location map:");
    try lines.append("60 56 37");
    try lines.append("56 93 4");
    return lines;
}
