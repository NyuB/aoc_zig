const std = @import("std");
const String = []const u8;

const ProtoField = struct {
    optional: bool = false,
    repeated: bool = false,
    name: String,
    proto_type: String,
    code: u16,
};

const ProtoMessage = struct {
    name: String,
    fields: []const ProtoField,
};

const ProtoParseError = error{
    InvalidSyntaxVersion,
    TokenError,
};

fn Lexer(comptime maxTokenCount: usize) type {
    return struct {
        arr: [maxTokenCount]Token = undefined,
        count: usize = 0,
        tokenizers: [17]Tokenizer,
        alive: [17]bool,
        const Self = @This();
        fn init() Self {
            var tokenizers: [17]Tokenizer = undefined;
            var alive: [17]bool = undefined;
            var res = Self{ .tokenizers = tokenizers, .alive = alive };
            res.resetTokenizers();
            return res;
        }

        const initTokenizers = [17]Tokenizer{
            Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init("enum", Token.Enum) },
            Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init("import", Token.Import) },
            Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init("message", Token.Message) },
            Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init("opion", Token.Option) },
            Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init("repeated", Token.Repeated) },
            Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init("rpc", Token.Rpc) },
            Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init("service", Token.Service) },
            Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init("syntax", Token.Syntax) },
            Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init("to", Token.To) },
            Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init("=", Token.Eq) },
            Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init(";", Token.SemiColumn) },
            Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init(",", Token.Comma) },
            Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init("{", Token.LBracket) },
            Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init("}", Token.RBracket) },
            Tokenizer{ .IdentifierTokenizer = IdentifierTokenizer.init() },
            Tokenizer{ .IntLiteralTokenizer = IntLiteralTokenizer.init() },
            Tokenizer{ .StringLiteralTokenizer = StringLiteralTokenizer.init() },
        };

        fn resetTokenizers(self: *Self) void {
            for (initTokenizers, 0..) |t, i| {
                self.tokenizers[i] = t;
                self.alive[i] = true;
            }
        }

        fn read(self: *Self, slice: String) void {
            var s = slice;
            var matched: ?Token = null;
            var matchIndex: usize = 0;
            while (s.len > 0 and (s[0] == ' ' or s[0] == '\t' or s[0] == '\n' or s[0] == '\r')) : (s = s[1..]) {}
            for (s) |c| {
                var itMatched = false;
                var itAccepted = false;
                for (&self.tokenizers, 0..) |*t, ti| {
                    if (self.alive[ti] and t.accept(c)) {
                        itAccepted = true;
                        if (!itMatched and t.matched()) {
                            matched = t.token(s);
                            itMatched = true;
                        }
                    } else {
                        self.alive[ti] = false;
                    }
                }
                if (!itAccepted) break;
                matchIndex += 1;
            }
            self.resetTokenizers();
            if (matchIndex > 0) {
                self.arr[self.count] = matched orelse unreachable;
                self.count += 1;
                self.read(s[matchIndex..]);
            }
        }
    };
}

const Token = union(enum) {
    // Keywords
    Enum,
    Import,
    Message,
    Option,
    Repeated,
    Rpc,
    Service,
    Syntax,
    To,
    Eq,
    SemiColumn,
    Comma,
    LBracket,
    RBracket,
    // Literals
    Identifier: String,
    IntLiteral: usize,
    StringLiteral: String,
};

const Tokenizer = union(enum) {
    IdentifierTokenizer: IdentifierTokenizer,
    IntLiteralTokenizer: IntLiteralTokenizer,
    KeywordTokenizer: KeywordTokenizer,
    StringLiteralTokenizer: StringLiteralTokenizer,

    fn matched(self: Tokenizer) bool {
        return switch (self) {
            inline else => |t| t.matched(),
        };
    }

    fn matchLen(self: Tokenizer) usize {
        return switch (self) {
            inline else => |t| t.matchLen,
        };
    }

    fn accept(self: *Tokenizer, c: u8) bool {
        return switch (self.*) {
            inline else => |*t| t.accept(c),
        };
    }

    fn token(self: Tokenizer, s: String) Token {
        return switch (self) {
            .KeywordTokenizer => |t| t.token,
            inline else => |t| t.token(s),
        };
    }
};

fn stringEquals(a: String, b: String) bool {
    return std.mem.eql(u8, a, b);
}

const KeywordTokenizer = struct {
    matchLen: usize,
    keyword: String,
    token: Token,

    fn matched(self: KeywordTokenizer) bool {
        return self.matchLen == self.keyword.len;
    }

    fn token(self: KeywordTokenizer, _: String) Token {
        return self.token;
    }

    fn accept(self: *KeywordTokenizer, c: u8) bool {
        if (self.matchLen < self.keyword.len and self.keyword[self.matchLen] == c) {
            self.matchLen += 1;
            return true;
        } else {
            return false;
        }
    }

    fn init(keyword: String, t: Token) KeywordTokenizer {
        return KeywordTokenizer{ .matchLen = 0, .keyword = keyword, .token = t };
    }
};

test "Keyword tokenizer" {
    var t = Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init("kw", Token.Enum) };
    try expect(t.accept('k'));
    try expect(t.accept('w'));
    try expect(t.matched());
    try expect(t.matchLen() == 2);

    try expectNot(t.accept('z'));
    try expect(t.matched());
    try expect(t.matchLen() == 2);

    t = Tokenizer{ .KeywordTokenizer = KeywordTokenizer.init("kw", Token.Enum) };
    try expect(t.accept('k'));
    try expectNot(t.accept('z'));
    try expectNot(t.matched());
}

const StringLiteralTokenizer = struct {
    matchLen: usize,
    escape: bool,
    over: bool,
    started: bool,

    fn matched(self: StringLiteralTokenizer) bool {
        return self.over;
    }

    fn token(self: StringLiteralTokenizer, content: String) Token {
        return Token{ .StringLiteral = content[1 .. 1 + self.matchLen - 2] };
    }

    fn accept(self: *StringLiteralTokenizer, c: u8) bool {
        if (self.over) return false;
        if (!self.started and c != '"') return false;
        if (c == '"') {
            if (self.escape) {
                self.escape = false;
            } else if (self.started) {
                self.over = true;
            } else {
                self.started = true;
            }
        } else if (c == '\\') {
            self.escape = !self.escape;
        }
        self.matchLen += 1;
        return true;
    }

    fn init() StringLiteralTokenizer {
        return StringLiteralTokenizer{ .matchLen = 0, .escape = false, .over = false, .started = false };
    }
};

test "String literal tokenizer" {
    var t = Tokenizer{ .StringLiteralTokenizer = StringLiteralTokenizer.init() };
    try expectNot(t.matched());
    try expect(t.accept('"'));
    try expect(t.accept('"'));
    try expect(t.matched());
    try expect(t.matchLen() == 2);

    t = Tokenizer{ .StringLiteralTokenizer = StringLiteralTokenizer.init() };
    try expect(t.accept('"'));
    try expect(t.accept('a'));
    try expect(t.accept('b'));
    try expect(t.accept('c'));
    try expect(t.accept('"'));
    // Finished once closed
    try expectNot(t.accept('"'));
    try expectNot(t.accept('a'));
    try expect(t.matched());
    try expect(t.matchLen() == 5);
    try std.testing.expectEqualStrings("abc", t.StringLiteralTokenizer.token("\"abc\"").StringLiteral);

    // Escape quotes with backslash
    t = Tokenizer{ .StringLiteralTokenizer = StringLiteralTokenizer.init() };
    try expect(t.accept('"'));
    try expect(t.accept('\\'));
    try expect(t.accept('"'));
    try expect(t.accept('"'));
    try expect(t.matched());
    try expect(t.matchLen() == 4);
}

const IdentifierTokenizer = struct {
    matchLen: usize,

    fn matched(self: IdentifierTokenizer) bool {
        return self.matchLen > 0;
    }

    fn accept(self: *IdentifierTokenizer, c: u8) bool {
        if (self.matchLen == 0 and letter(c)) {
            self.matchLen += 1;
            return true;
        }
        if (self.matchLen > 0 and body(c)) {
            self.matchLen += 1;
            return true;
        }
        return false;
    }

    fn letter(c: u8) bool {
        return ('a' <= c and 'z' >= c) or ('A' <= c and 'Z' >= c);
    }

    fn digit(c: u8) bool {
        return ('0' <= c and '9' >= c);
    }

    fn separator(c: u8) bool {
        return c == '_';
    }

    fn body(c: u8) bool {
        return letter(c) or digit(c) or separator(c);
    }

    fn init() IdentifierTokenizer {
        return IdentifierTokenizer{ .matchLen = 0 };
    }

    fn token(self: IdentifierTokenizer, s: String) Token {
        return Token{ .Identifier = s[0..self.matchLen] };
    }
};

test "Identifier tokenizer" {
    var t = Tokenizer{ .IdentifierTokenizer = IdentifierTokenizer.init() };
    try expectNot(t.matched());
    try expect(t.accept('a'));
    try expect(t.accept('_'));
    try expect(t.accept('Z'));
    try expect(t.accept('1'));
    try expect(t.matched());
    try expect(t.matchLen() == 4);

    // Accept alphanum and underscore only
    try expectNot(t.accept('-'));

    // Must start with a letter
    t = Tokenizer{ .IdentifierTokenizer = IdentifierTokenizer.init() };
    try expectNot(t.accept('7'));
    try expectNot(t.accept('_'));
}

const IntLiteralTokenizer = struct {
    matchLen: usize,

    fn matched(self: IntLiteralTokenizer) bool {
        return self.matchLen > 0;
    }

    fn accept(self: *IntLiteralTokenizer, c: u8) bool {
        if (c >= '0' and c <= '9') {
            self.matchLen += 1;
            return true;
        } else {
            return false;
        }
    }

    fn init() IntLiteralTokenizer {
        return IntLiteralTokenizer{ .matchLen = 0 };
    }

    fn token(self: IntLiteralTokenizer, s: String) Token {
        return Token{ .IntLiteral = std.fmt.parseInt(usize, s[0..self.matchLen], 10) catch unreachable };
    }
};

test "Int literal tokenizer" {
    var t = Tokenizer{ .IntLiteralTokenizer = IntLiteralTokenizer.init() };
    try expect(t.accept('1'));
    try expect(t.accept('2'));
    try expect(t.accept('3'));
    try expect(t.accept('4'));
    try expect(t.accept('5'));
    try expect(t.accept('6'));
    try expect(t.accept('7'));
    try expect(t.accept('8'));
    try expect(t.accept('9'));
    try expect(t.accept('0'));

    try expect(t.matched());
    try expect(t.matchLen() == 10);

    try expectNot(t.accept('u'));
}

test "Lexer" {
    const file = @embedFile("single_field.proto");
    var lexer = Lexer(50).init();
    lexer.read(file);
    var expected: []const Token = &[_]Token{
            Token.Syntax,
            Token.Eq,
            Token{ .StringLiteral = "proto3" },
            Token.SemiColumn,
            Token.Message,
            Token{ .Identifier = "Single" },
            Token.LBracket,
            Token{ .Identifier = "int32" },
            Token{ .Identifier = "foo" },
            Token.Eq,
            Token{ .IntLiteral = 1 },
            Token.SemiColumn,
            Token.RBracket,
        };
    try std.testing.expectEqualDeep(
        expected,
        lexer.arr[0..lexer.count],
    );
}

const expect = std.testing.expect;
fn expectNot(b: bool) !void {
    try expect(!b);
}
