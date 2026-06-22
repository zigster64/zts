const std = @import("std");

const Mode = enum {
    find_directive,
    reading_directive_name,
    content_line,
};

// s will return the section from the data, as a comptime known string
pub fn s(comptime str: []const u8, comptime directive: ?[]const u8) []const u8 {
    comptime var mode: Mode = .find_directive;
    comptime var maybe_directive_start = 0;
    comptime var directive_start = 0;
    comptime var content_start = 0;
    comptime var content_end = 0;
    comptime var last_start_of_line = 0;

    @setEvalBranchQuota(1_000_000);

    inline for (str, 0..) |c, index| {
        switch (mode) {
            .find_directive => {
                switch (c) {
                    '.' => {
                        maybe_directive_start = index;
                        mode = .reading_directive_name;
                        // @compileLog("maybe new directive at", maybe_directive_start);
                    },
                    ' ', '\t' => {}, // eat whitespace
                    '\n' => {
                        last_start_of_line = index + 1;
                    },
                    else => mode = .content_line,
                }
            },
            .reading_directive_name => {
                switch (c) {
                    '\n' => {
                        if (directive == null) {
                            // then content is the first unlabelled block, so we can return now
                            return str[0..last_start_of_line];
                        }
                        if (content_end > 0) {
                            // that really was a directive following our content then, so we now have the content we are looking for
                            content_end = last_start_of_line;
                            return str[content_start..content_end];
                        }
                        // found a new directive - we need to patch the value of the previous content then
                        directive_start = maybe_directive_start;
                        const directive_name = if (str[index - 1] == '\r')
                            str[directive_start + 1 .. index - 1]
                        else
                            str[directive_start + 1 .. index];
                        content_start = index + 1;
                        if (comptime std.mem.eql(u8, directive_name, directive.?)) {
                            content_end = str.len - 1;
                            // @compileLog("found directive in data", directive_name, "starts at", content_start, "runs to", content_end);
                        }
                        last_start_of_line = index + 1;
                        mode = .find_directive;
                    },
                    '\x01'...'\t', '\x0B'...'\x1F', ' '...'/', ':'...'@', '{'...'}', '['...'^', '`' => { // invalid chars for directive name
                        // @compileLog("false alarm scanning directive, back to content", str[maybe_directive_start .. index + 1]);
                        mode = .content_line;
                        maybe_directive_start = directive_start;
                    },
                    else => {},
                }
            },
            .content_line => { // just eat the rest of the line till the next line
                switch (c) {
                    '\n' => {
                        mode = .find_directive;
                        last_start_of_line = index + 1;
                    },
                    else => {},
                }
            },
        }
    }

    if (content_end > 0) {
        return str[content_start .. content_end + 1];
    }

    if (directive == null) {
        return str;
    }

    const directiveNotFound = "Data does not contain any section labelled '" ++ directive.? ++ "'\nMake sure there is a line in your data that start with ." ++ directive.?;
    @compileError(directiveNotFound);
}

// lookup will return the section from the data, as a runtime known string, or null if not found
pub fn lookup(str: []const u8, directive: ?[]const u8) ?[]const u8 {
    var mode: Mode = .find_directive;
    var maybe_directive_start: usize = 0;
    var directive_start: usize = 0;
    var content_start: usize = 0;
    var content_end: usize = 0;
    var last_start_of_line: usize = 0;

    for (str, 0..) |c, index| {
        switch (mode) {
            .find_directive => {
                switch (c) {
                    '.' => {
                        maybe_directive_start = index;
                        mode = .reading_directive_name;
                        // @compileLog("maybe new directive at", maybe_directive_start);
                    },
                    ' ', '\t' => {}, // eat whitespace
                    '\n' => {
                        last_start_of_line = index + 1;
                    },
                    else => mode = .content_line,
                }
            },
            .reading_directive_name => {
                switch (c) {
                    '\n' => {
                        if (directive == null) {
                            // then content is the first unlabelled block, so we can return now
                            return str[0..last_start_of_line];
                        }
                        if (content_end > 0) {
                            // that really was a directive following our content then, so we now have the content we are looking for
                            content_end = last_start_of_line;
                            return str[content_start..content_end];
                        }
                        // found a new directive - we need to patch the value of the previous content then
                        directive_start = maybe_directive_start;
                        const directive_name = if (str[index - 1] == '\r')
                            str[directive_start + 1 .. index - 1]
                        else
                            str[directive_start + 1 .. index];
                        content_start = index + 1;
                        if (std.mem.eql(u8, directive_name, directive.?)) {
                            content_end = str.len - 1;
                            // @compileLog("found directive in data", directive_name, "starts at", content_start, "runs to", content_end);
                        }
                        last_start_of_line = index + 1;
                        mode = .find_directive;
                    },
                    '\x00'...'\t', '\x0B'...'\x1F', ' '...'/', ':'...'@', '{'...'}', '['...'^', '`' => { // invalid chars for directive name
                        // @compileLog("false alarm scanning directive, back to content", str[maybe_directive_start .. index + 1]);
                        mode = .content_line;
                        maybe_directive_start = directive_start;
                    },
                    else => {},
                }
            },
            .content_line => { // just eat the rest of the line till the next line
                switch (c) {
                    '\n' => {
                        mode = .find_directive;
                        last_start_of_line = index + 1;
                    },
                    else => {},
                }
            },
        }
    }

    if (content_end > 0) {
        return str[content_start .. content_end + 1];
    }

    if (directive == null) {
        return str;
    }

    return null;
}

pub fn printHeader(comptime str: []const u8, args: anytype, out: anytype) !void {
    try out.print(comptime s(str, null), args);
}

pub fn print(comptime str: []const u8, comptime section: []const u8, args: anytype, out: anytype) !void {
    try out.print(comptime s(str, section), args);
}

pub fn writeHeader(comptime str: []const u8, out: anytype) !void {
    try out.writeAll(comptime s(str, null));
}

pub fn write(comptime str: []const u8, comptime section: []const u8, out: anytype) !void {
    try out.writeAll(comptime s(str, section));
}

pub fn writeDynamic(str: []const u8, section: []const u8, out: anytype) !void {
    const data = lookup(str, section);
    if (data != null) try out.writeAll(data.?);
}

// ---- #enumEach directive support ----

/// A segment of an enumEach template body: literal text or an enum value interpolation.
const EnumSegment = union(enum) {
    literal: []const u8, // plain text to write verbatim
    enum_self, // {{.}} — writes @tagName of the current enum field
    enum_field: []const u8, // {{.method}} — calls method on current enum value
};

/// Extracts the body text from between #enumEach and #endenumEach within section content.
/// The section must contain exactly one #enumEach ... #endenumEach block.
fn extractEnumBody(comptime content: []const u8) []const u8 {
    @setEvalBranchQuota(100_000);
    const marker = "#enumEach";
    const end_marker = "#endenumEach";

    const start_idx = comptime std.mem.indexOf(u8, content, marker) orelse
        @compileError("Section does not contain #enumEach directive");

    // body starts after the newline following #enumEach
    const body_start = comptime std.mem.indexOfScalarPos(u8, content, start_idx, '\n') orelse
        @compileError("Malformed #enumEach directive: missing newline after type name");

    const end_idx = comptime std.mem.indexOfPos(u8, content, body_start, end_marker) orelse
        @compileError("Missing #endenumEach to close #enumEach block");

    // body runs from after the #enumEach line up to (not including) #endenumEach.
    // The newline(s) before #endenumEach are part of the body and get repeated
    // on every iteration — this is how users put separators between rows.
    return content[body_start + 1 .. end_idx];
}

/// Parses an enumEach template body into segments by splitting on {{...}} markers.
/// Each segment is either literal text, {{.}} (enum tag name), or {{.method}} (method call).
fn parseEnumTemplate(comptime body: []const u8) []const EnumSegment {
    @setEvalBranchQuota(1_000_000);

    comptime var segments: [64]EnumSegment = undefined;
    comptime var seg_count: usize = 0;

    comptime var i: usize = 0;
    comptime var lit_start: usize = 0;

    while (i < body.len) {
        if (i + 1 < body.len and body[i] == '{' and body[i + 1] == '{') {
            // flush preceding literal if non-empty
            if (i > lit_start) {
                segments[seg_count] = .{ .literal = body[lit_start..i] };
                seg_count += 1;
            }
            const marker_inner_start = i + 2;
            const close = comptime std.mem.indexOfPos(u8, body, marker_inner_start, "}}") orelse
                @compileError("Unclosed '{{' marker in enum template");
            const inner = body[marker_inner_start..close];

            if (inner.len == 1 and inner[0] == '.') {
                segments[seg_count] = .enum_self;
            } else if (inner.len > 1 and inner[0] == '.') {
                segments[seg_count] = .{ .enum_field = inner[1..] };
            } else {
                @compileError("Invalid marker in enum template: '{{" ++ inner ++ "}}'. Expected {{.}} or {{.methodName}}");
            }
            seg_count += 1;
            i = close + 2;
            lit_start = i;
        } else {
            i += 1;
        }
    }

    // flush trailing literal
    if (lit_start < body.len) {
        segments[seg_count] = .{ .literal = body[lit_start..body.len] };
        seg_count += 1;
    }

    return segments[0..seg_count];
}

/// Writes a value returned by an enum method to the output writer.
/// Handles []const u8, integers, and floats. Other types print a placeholder.
fn writeResult(out: anytype, result: anytype) !void {
    const T = @TypeOf(result);
    switch (@typeInfo(T)) {
        .pointer => |ptr| {
            if (ptr.size == .slice and ptr.child == u8) {
                try out.writeAll(result);
                return;
            }
        },
        .int, .comptime_int => {
            try out.print("{d}", .{result});
            return;
        },
        .float, .comptime_float => {
            try out.print("{d}", .{result});
            return;
        },
        else => {},
    }
    try out.print("{s}", .{"[unprintable]"});
}

/// printEnum renders a template section that contains an #enumEach directive.
///
/// The section content must be of the form:
///   #enumEach TypeName
///   body with {{.method}} interpolations
///   #endenumEach
///
/// At comptime, the body is unrolled once per field of the enum type,
/// producing a sequence of calls to out.writeAll / out.print.
///
/// EnumType is passed explicitly from the call site so that comptime
/// type resolution is trivial and does not require @import in the
/// template parser.
pub fn printEnum(
    comptime tmpl: []const u8,
    comptime section: []const u8,
    comptime EnumType: type,
    out: anytype,
) !void {
    if (@typeInfo(EnumType) != .@"enum") {
        @compileError("printEnum requires an enum type, got " ++ @typeName(EnumType));
    }

    const content = comptime s(tmpl, section);
    const body = comptime extractEnumBody(content);
    const segments = comptime parseEnumTemplate(body);

    inline for (comptime std.meta.fields(EnumType)) |field| {
        const val: EnumType = @enumFromInt(field.value);
        inline for (segments) |seg| {
            switch (seg) {
                .literal => |lit| try out.writeAll(lit),
                .enum_self => try out.writeAll(@tagName(val)),
                .enum_field => |method_name| {
                    const method = @field(EnumType, method_name);
                    const result = @call(.auto, method, .{val});
                    try writeResult(out, result);
                },
            }
        }
    }
}

// ---- test utilities ----

const TestWriter = struct {
    list: *std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn writeAll(self: @This(), bytes: []const u8) error{OutOfMemory}!void {
        try self.list.appendSlice(self.allocator, bytes);
    }

    pub fn print(self: @This(), comptime fmt: []const u8, args: anytype) error{OutOfMemory}!void {
        const formatted = try std.fmt.allocPrint(self.allocator, fmt, args);
        defer self.allocator.free(formatted);
        try self.list.appendSlice(self.allocator, formatted);
    }

    pub fn write(self: @This(), bytes: []const u8) error{OutOfMemory}!usize {
        try self.list.appendSlice(self.allocator, bytes);
        return bytes.len;
    }
};

fn makeTestWriter(list: *std.ArrayList(u8), allocator: std.mem.Allocator) TestWriter {
    return .{ .list = list, .allocator = allocator };
}

test "comptime single character before a '.'" {
    const data =
        \\  something
        \\  x.not_a_label();
        \\  x.also_not_a_label
        \\  .label
        \\  label content
    ;

    // test that we can use the data as a comptime known format to pass through print
    var formatted_data = try std.fmt.allocPrint(std.testing.allocator, s(data, null), .{});
    try std.testing.expectEqualSlices(u8, "  something\n  x.not_a_label();\n  x.also_not_a_label\n", formatted_data);
    std.testing.allocator.free(formatted_data);

    formatted_data = try std.fmt.allocPrint(std.testing.allocator, s(data, "label"), .{});
    try std.testing.expectEqualSlices(u8, "  label content", formatted_data);
    std.testing.allocator.free(formatted_data);
}

test "runtime single character before a '.'" {
    const data =
        \\  something
        \\  x.not_a_label();
        \\  x.also_not_a_label
        \\  .label
        \\  label content
    ;

    // test that we can use the data during runtime
    var formatted_data = try std.fmt.allocPrint(std.testing.allocator, "{?s}", .{lookup(data, null)});
    try std.testing.expectEqualSlices(u8, "  something\n  x.not_a_label();\n  x.also_not_a_label\n", formatted_data);
    std.testing.allocator.free(formatted_data);

    formatted_data = try std.fmt.allocPrint(std.testing.allocator, "{?s}", .{lookup(data, "label")});
    try std.testing.expectEqualSlices(u8, "  label content", formatted_data);
    std.testing.allocator.free(formatted_data);
}

test "data with no sections, and formatting" {
    const data = @embedFile("testdata/all.txt");
    try std.testing.expectEqual(data.len, 78);

    // test that we can use the data as a comptime known format to pass through print
    const formatted_data = try std.fmt.allocPrint(std.testing.allocator, data, .{"embedded formatting"});
    try std.testing.expectEqual(formatted_data.len, 94);
    std.testing.allocator.free(formatted_data);

    // TODO - add a test that calling printHeader() on a file with no sections accurately dumps the whole file
    // try printHeader(data, .{"hi from the formatter"}, std.io.getStdErr().writer());
}

test "foobar with multiple sections and no formatting" {
    const data = @embedFile("testdata/foobar1.txt");
    try std.testing.expectEqual(data.len, 91);
    const foo = s(data, "foo");
    try std.testing.expectEqualSlices(u8, "I like the daytime\n", foo);
    const bar = s(data, "bar");
    try std.testing.expectEqualSlices(u8, "I prefer the nighttime\n", bar);
    const empty = s(data, "empty");
    try std.testing.expectEqualSlices(u8, "", empty);
    const notempty = s(data, "notempty");
    try std.testing.expectEqualSlices(u8, "This has some content\n", notempty);
}

test "html file with multiple sections and formatting" {
    var list: std.ArrayList(u8) = .{ .items = &.{}, .capacity = 0 };
    list = try std.ArrayList(u8).initCapacity(std.testing.allocator, 0);
    defer list.deinit(std.testing.allocator);

    const out = makeTestWriter(&list, std.testing.allocator);
    const data = @embedFile("testdata/customer_details.html");

    const Invoice = struct {
        date: []const u8,
        details: []const u8,
        amount: f32,
    };

    const customer = .{
        .name = "Joe Blow",
        .address = "21 Main Street",
        .credit = 100.0,
    };
    const invoices = &[_]Invoice{
        .{ .date = "2023-10-01", .details = "New Hoodie", .amount = 80.99 },
        .{ .date = "2023-10-03", .details = "Hotdog with Sauce", .amount = 4.50 },
        .{ .date = "2023-10-04", .details = "Mystery Gift", .amount = 12.00 },
        .{ .date = "2023-10-12", .details = "Model Aircraft", .amount = 48.00 },
        .{ .date = "2023-10-24", .details = "Chocolate Milkshake", .amount = 80.99 },
    };

    try printHeader(data, .{}, out);

    // print the customer details
    try print(data, "customer_details", customer, out);

    // print a table of customer invoices
    try print(data, "invoice_table", .{}, out);
    var total: f32 = 0.0;
    inline for (invoices) |inv| {
        try print(data, "invoice_row", inv, out);
        total += inv.amount;
    }
    try print(data, "invoice_total", .{ .total = total }, out);

    // uncomment these to see the output on the console
    // var stderr = std.io.getStdErr().writer();
    // try stderr.writeAll(list.items);

    // compare to golden file
    const expected_data = @embedFile("testdata/customer_details.expected.html");
    try std.testing.expectEqualSlices(u8, expected_data, list.items);
}

test "statement in english or german based on LANG env var - runtime only" {
    var list: std.ArrayList(u8) = .{ .items = &.{}, .capacity = 0 };
    list = try std.ArrayList(u8).initCapacity(std.testing.allocator, 0);
    defer list.deinit(std.testing.allocator);

    const out = makeTestWriter(&list, std.testing.allocator);
    const data = @embedFile("testdata/you-owe-us.txt");

    // use environment or default to english
    var lang = "en";

    try writeHeader(data, out);
    try writeDynamic(data, "terms_" ++ lang, out);

    // try it again in german
    lang = "de";
    try writeDynamic(data, "terms_" ++ lang, out);

    const expected_data = @embedFile("testdata/english_german_statement.txt");
    try std.testing.expectEqualSlices(u8, expected_data, list.items);
}

test "enumEach - iterate enum fields with {{.method}} interpolation" {
    const Grade = enum {
        veteran,
        elite,
        regular,

        pub fn slug(self: @This()) []const u8 {
            return switch (self) {
                .veteran => "vet",
                .elite => "elite",
                .regular => "reg",
            };
        }

        pub fn label(self: @This()) []const u8 {
            return @tagName(self);
        }
    };

    var list: std.ArrayList(u8) = .{ .items = &.{}, .capacity = 0 };
    list = try std.ArrayList(u8).initCapacity(std.testing.allocator, 0);
    defer list.deinit(std.testing.allocator);

    const out = makeTestWriter(&list, std.testing.allocator);
    const data = @embedFile("testdata/enum_options.txt");

    try printEnum(data, "options", Grade, out);

    const expected =
        \\<option value="vet">veteran</option>
        \\<option value="elite">elite</option>
        \\<option value="reg">regular</option>
        \\
    ;
    try std.testing.expectEqualSlices(u8, expected, list.items);
}

test "enumEach - {{.}} outputs @tagName for each field" {
    const Color = enum {
        red,
        green,
        blue,
    };

    var list: std.ArrayList(u8) = .{ .items = &.{}, .capacity = 0 };
    list = try std.ArrayList(u8).initCapacity(std.testing.allocator, 0);
    defer list.deinit(std.testing.allocator);

    const out = makeTestWriter(&list, std.testing.allocator);

    // inline template string using {{.}} for the enum tag name
    const data =
        \\.colors
        \\#enumEach Color
        \\{{.}},
        \\#endenumEach
    ;

    try printEnum(data, "colors", Color, out);

    const expected =
        \\red,
        \\green,
        \\blue,
        \\
    ;
    try std.testing.expectEqualSlices(u8, expected, list.items);
}

test "empty directive" {}
