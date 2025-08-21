const std = @import("std");

const Mode = enum {
    find_directive,
    reading_directive_name,
    content_line,
    content_start,
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
                    else => mode = .content_start,
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
                        mode = .content_start;
                    },
                    ' ', '\t', '.', '{', '}', '[', ']', ':' => { // invalid chars for directive name
                        // @compileLog("false alarm scanning directive, back to content", str[maybe_directive_start .. index + 1]);
                        mode = .content_start;
                        maybe_directive_start = directive_start;
                    },
                    else => {},
                }
            },
            .content_start => {
                // if the first non-whitespace char of content is a .
                // then we are in find directive mode !
                switch (c) {
                    '\n' => {
                        mode = .find_directive;
                        last_start_of_line = index + 1;
                    },
                    ' ', '\t' => {}, // eat whitespace
                    '.' => {
                        // thinks we are looking for content, but last directive
                        // was empty, so start a new directive on this line
                        maybe_directive_start = index;
                        last_start_of_line = content_start;
                        mode = .reading_directive_name;
                    },
                    else => {
                        mode = .content_line;
                    },
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
                    else => mode = .content_start,
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
                        mode = .content_start;
                    },
                    ' ', '\t', '.', '{', '}', '[', ']', ':' => { // invalid chars for directive name
                        // @compileLog("false alarm scanning directive, back to content", str[maybe_directive_start .. index + 1]);
                        mode = .content_start;
                        maybe_directive_start = directive_start;
                    },
                    else => {},
                }
            },
            .content_start => {
                // if the first non-whitespace char of content is a .
                // then we are in find directive mode !
                switch (c) {
                    '\n' => {
                        mode = .find_directive;
                        last_start_of_line = index + 1;
                    },
                    ' ', '\t' => {}, // eat whitespace
                    '.' => {
                        // thinks we are looking for content, but last directive
                        // was empty, so start a new directive on this line
                        maybe_directive_start = index;
                        last_start_of_line = content_start;
                        mode = .reading_directive_name;
                    },
                    else => {
                        mode = .content_line;
                    },
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

pub fn printHeader(comptime str: []const u8, args: anytype, out: *std.Io.Writer) !void {
    try out.print(comptime s(str, null), args);
    try out.flush();
}

pub fn print(comptime str: []const u8, comptime section: []const u8, args: anytype, out: *std.Io.Writer) !void {
    try out.print(comptime s(str, section), args);
    try out.flush();
}

pub fn writeHeader(str: []const u8, out: *std.Io.Writer) !void {
    const data = lookup(str, null);
    if (data != null) {
        try out.writeAll(data.?);
        try out.flush();
    }
}

pub fn write(str: []const u8, section: []const u8, out: *std.Io.Writer) !void {
    const data = lookup(str, section);
    if (data != null) {
        try out.writeAll(data.?);
        try out.flush();
    }
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

// test "html file with multiple sections and formatting" {
//     var list = std.ArrayList(u8).init(std.testing.allocator, 100);
//     defer list.deinit();
//
//     // var out = std.io.getStdErr().writer();
//     const out = list.writer();
//     const data = @embedFile("testdata/customer_details.html");
//
//     const Invoice = struct {
//         date: []const u8,
//         details: []const u8,
//         amount: f32,
//     };
//
//     const customer = .{
//         .name = "Joe Blow",
//         .address = "21 Main Street",
//         .credit = 100.0,
//     };
//     const invoices = &[_]Invoice{
//         .{ .date = "2023-10-01", .details = "New Hoodie", .amount = 80.99 },
//         .{ .date = "2023-10-03", .details = "Hotdog with Sauce", .amount = 4.50 },
//         .{ .date = "2023-10-04", .details = "Mystery Gift", .amount = 12.00 },
//         .{ .date = "2023-10-12", .details = "Model Aircraft", .amount = 48.00 },
//         .{ .date = "2023-10-24", .details = "Chocolate Milkshake", .amount = 80.99 },
//     };
//
//     try printHeader(data, .{}, out);
//
//     // print the customer details
//     try print(data, "customer_details", customer, out);
//
//     // print a table of customer invoices
//     try print(data, "invoice_table", .{}, out);
//     var total: f32 = 0.0;
//     inline for (invoices) |inv| {
//         try print(data, "invoice_row", inv, out);
//         total += inv.amount;
//     }
//     try print(data, "invoice_total", .{ .total = total }, out);
//
//     // uncomment these to see the output on the console
//     // var stderr = std.io.getStdErr().writer();
//     // try stderr.writeAll(list.items);
//
//     // compare to golden file
//     const expected_data = @embedFile("testdata/customer_details.expected.html");
//     try std.testing.expectEqualSlices(u8, expected_data, list.items);
// }

// test "statement in english or german based on LANG env var - runtime only" {
//     var list = std.ArrayList(u8).init(std.testing.allocator);
//     defer list.deinit();
//
//     // var out = std.io.getStdErr().writer();
//     const out = list.writer();
//     const data = @embedFile("testdata/you-owe-us.txt");
//
//     // use environment
//     var lang = std.posix.getenv("LANG").?[0..2];
//
//     try writeHeader(data, out);
//     try write(data, "terms_" ++ lang, out);
//
//     // try it again in german
//     lang = "de";
//     try write(data, "terms_" ++ lang, out);
//
//     const expected_data = @embedFile("testdata/english_german_statement.txt");
//     try std.testing.expectEqualSlices(u8, expected_data, list.items);
// }

test "empty directive" {}
