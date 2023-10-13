const std = @import("std");

const Mode = enum {
    find_directive,
    reading_directive_name,
    content_line,
};

// s will return the section from the data, as a comptime known string
pub fn s(comptime str: []const u8, comptime directive: []const u8) []const u8 {
    comptime var mode: Mode = .find_directive;
    comptime var maybe_directive_start = 0;
    comptime var directive_start = 0;
    comptime var content_start = 0;
    comptime var content_end = 0;
    comptime var last_start_of_line = 0;

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
                        if (content_end > 0) {
                            // that really was a directive then, so we now have the content we are looking for
                            content_end = last_start_of_line;
                            return str[content_start..content_end];
                        }
                        // found a new directive - we need to patch the value of the previous content then
                        directive_start = maybe_directive_start;
                        const directive_name = str[directive_start + 1 .. index];
                        content_start = index + 1;
                        if (comptime std.mem.eql(u8, directive_name, directive)) {
                            content_end = str.len - 1;
                            // @compileLog("found directive in data", directive_name, "starts at", content_start, "runs to", content_end);
                        }
                        mode = .content_line;
                    },
                    ' ', '\t', '.', '-', '{', '}', '[', ']', ':' => { // invalid chars for directive name
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
        return str[content_start..content_end];
    }

    comptime var directiveNotFound = "Data does not contain any section labelled '" ++ directive ++ "'\nMake sure there is a line in your data that start with ." ++ directive;
    @compileError(directiveNotFound);
}

pub fn print(out: anytype, comptime str: []const u8, comptime section: []const u8, args: anytype) !void {
    try out.print(comptime s(str, section), args);
}

test "all.txt" {
    var out = std.io.getStdErr().writer();
    try std.testing.expectEqual(data.len, 78);

    // test that we can use the data as a comptime known format to pass through print
    var formatted_data = try std.fmt.allocPrint(std.testing.allocator, data, .{"embedded formatting"});
    defer std.testing.allocator.free(formatted_data);
    try std.testing.expectEqual(formatted_data.len, 94);
}

test "foobar with multiple sections" {
    var out = std.io.getStdErr().writer();
    try out.writeAll("\n-----------------foobar.txt template with multiple sections----------------------\n");

    const data = @embedFile("testdata/foobar.txt");

    const foo = s(data, "foo");
    _ = foo;
    // try std.testing.expectEqual(55, foo.len);
    const bar = s(data, "bar");
    _ = bar;
    // try std.testing.expectEqual(55, bar.len);

    // expect compile error
    // var xx = s(data, "xx");

    try out.print("Whole contents of foobar.txt is:\n---------------\n{s}\n---------------\n", .{data});

    try out.print("foo = '{s}'\n", .{s(data, "foo")});
    try out.print("bar = '{s}'\n", .{s(data, "bar")});

    // is the return of s a valid comptime string ?
    try out.print("-------foo as comptime format-----\n", .{});
    try out.print(s(data, "foo"), .{});

    try out.print("-------use print helper function-----\n", .{});
    try print(out, data, "foo", .{});
}
