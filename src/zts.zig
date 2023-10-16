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
                        const directive_name = str[directive_start + 1 .. index];
                        content_start = index + 1;
                        if (comptime std.mem.eql(u8, directive_name, directive.?)) {
                            content_end = str.len - 1;
                            // @compileLog("found directive in data", directive_name, "starts at", content_start, "runs to", content_end);
                        }
                        mode = .content_line;
                    },
                    ' ', '\t', '.', '{', '}', '[', ']', ':' => { // invalid chars for directive name
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

    comptime var directiveNotFound = "Data does not contain any section labelled '" ++ directive.? ++ "'\nMake sure there is a line in your data that start with ." ++ directive.?;
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
                        const directive_name = str[directive_start + 1 .. index];
                        content_start = index + 1;
                        if (std.mem.eql(u8, directive_name, directive.?)) {
                            content_end = str.len - 1;
                            // @compileLog("found directive in data", directive_name, "starts at", content_start, "runs to", content_end);
                        }
                        mode = .content_line;
                    },
                    ' ', '\t', '.', '{', '}', '[', ']', ':' => { // invalid chars for directive name
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

pub fn printSection(comptime str: []const u8, comptime section: []const u8, args: anytype, out: anytype) !void {
    try out.print(comptime s(str, section), args);
}

pub fn writeHeader(str: []const u8, out: anytype) !void {
    const data = lookup(str, null);
    if (data != null) try out.writeAll(data.?);
}

pub fn writeSection(str: []const u8, section: []const u8, out: anytype) !void {
    const data = lookup(str, section);
    if (data != null) try out.writeAll(data.?);
}

test "data with no sections, and formatting" {
    const data = @embedFile("testdata/all.txt");
    try std.testing.expectEqual(data.len, 78);

    // test that we can use the data as a comptime known format to pass through print
    var formatted_data = try std.fmt.allocPrint(std.testing.allocator, data, .{"embedded formatting"});
    try std.testing.expectEqual(formatted_data.len, 94);
    std.testing.allocator.free(formatted_data);

    // TODO - add a test that calling printHeader() on a file with no sections accurately dumps the whole file
    // try printHeader(data, .{"hi from the formatter"}, std.io.getStdErr().writer());
}

test "foobar with multiple sections and no formatting" {
    const data = @embedFile("testdata/foobar1.txt");
    try std.testing.expectEqual(data.len, 52);
    const foo = s(data, "foo");
    try std.testing.expectEqualSlices(u8, foo, "I like the daytime\n");
    const bar = s(data, "bar");
    try std.testing.expectEqualSlices(u8, bar, "I prefer the nighttime\n");
}

test "html file with multiple sections and formatting" {
    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    // var out = std.io.getStdErr().writer();
    var out = list.writer();
    const data = @embedFile("testdata/customer_details.html");

    const Invoice = struct {
        date: []const u8,
        details: []const u8,
        amount: f32,
    };

    var customer = .{
        .name = "Joe Blow",
        .address = "21 Main Street",
        .credit = 100.0,
    };
    var invoices = &[_]Invoice{
        .{ .date = "2023-10-01", .details = "New Hoodie", .amount = 80.99 },
        .{ .date = "2023-10-03", .details = "Hotdog with Sauce", .amount = 4.50 },
        .{ .date = "2023-10-04", .details = "Mystery Gift", .amount = 12.00 },
        .{ .date = "2023-10-12", .details = "Model Aircraft", .amount = 48.00 },
        .{ .date = "2023-10-24", .details = "Chocolate Milkshake", .amount = 80.99 },
    };

    try printHeader(data, .{}, out);

    // print the customer details
    try printSection(data, "customer_details", customer, out);

    // print a table of customer invoices
    try printSection(data, "invoice_table", .{}, out);
    var total: f32 = 0.0;
    inline for (invoices) |inv| {
        try printSection(data, "invoice_row", inv, out);
        total += inv.amount;
    }
    try printSection(data, "invoice_total", .{ .total = total }, out);

    // uncomment these to see the output on the console
    // var stderr = std.io.getStdErr().writer();
    // try stderr.writeAll(list.items);

    // compare to golden file
    const expected_data = @embedFile("testdata/customer_details.expected.html");
    try std.testing.expectEqualSlices(u8, expected_data, list.items);
}

test "statement in english or german based on LANG env var - runtime only" {
    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    // var out = std.io.getStdErr().writer();
    var out = list.writer();
    const data = @embedFile("testdata/you-owe-us.txt");

    // use environment
    var lang = std.os.getenv("LANG").?[0..2];

    try writeHeader(data, out);
    try writeSection(data, "terms_" ++ lang, out);

    // try it again in german
    lang = "de";
    try writeSection(data, "terms_" ++ lang, out);

    const expected_data = @embedFile("testdata/english_german_statement.txt");
    try std.testing.expectEqualSlices(u8, expected_data, list.items);
}
