const std = @import("std");

const Mode = enum {
    find_directive,
    reading_directive_name,
    content_line,
};

pub fn Template(comptime path: []const u8) type {
    @setEvalBranchQuota(500000);
    comptime var str = @embedFile(path);
    const decls = &[_]std.builtin.Type.Declaration{};

    const all = std.builtin.Type.StructField{
        .name = "all",
        .type = *const [str.len]u8,
        .is_comptime = true,
        .alignment = 1,
        .default_value = @ptrCast(&str[0..]),
    };

    // empty strings, or strings that dont start with a .directive - just map the whole string to .all and return early
    if (str.len < 1 or str[0] != '.') {
        comptime var fields: [1]std.builtin.Type.StructField = undefined;
        fields[0] = all;

        return @Type(.{
            .Struct = .{
                .layout = .Auto,
                .fields = &fields,
                .decls = decls,
                .is_tuple = false,
            },
        });
    }

    // PASS 1 - just count up the number of directives, so we can create the fields array of known size
    var mode: Mode = .find_directive;
    var num_fields = 0;
    inline for (str) |c| {
        // @compileLog(c);
        switch (mode) {
            .find_directive => {
                switch (c) {
                    '.' => mode = .reading_directive_name,
                    ' ', '\n' => {},
                    else => mode = .content_line,
                }
            },
            .reading_directive_name => {
                switch (c) {
                    '\n' => {
                        // got the end of a directive !
                        num_fields += 1;
                        mode = .find_directive;
                    },
                    ' ', '\t', '.', '-', '{', '}', '[', ']', ':' => mode = .content_line,
                    else => {},
                }
            },
            .content_line => {
                switch (c) {
                    '\n' => mode = .find_directive,
                    else => {},
                }
            },
        }
    }

    // @compileLog("num_fields =", num_fields);
    if (num_fields < 1) {
        @compileError("No fields found");
    }

    // now we know how many fields there should be, so is safe to statically define the fields array
    comptime var fields: [num_fields + 1]std.builtin.Type.StructField = undefined;
    fields[0] = all;

    var directive_start = 0;
    var maybe_directive_start = 0;
    var content_start = 0;
    var field_num = 1;

    // PASS 2
    // this is a bit more involved, as we cant allocate, and we want to do this in 1 single sweep of the data.
    // Scan through the data again, looking for a directive, and keep track of the offset of the start of content.
    // It uses 2 vars - maybe_directive_start is used when it thinks there might be a new directive, which
    // reverts back to the last good directive_start when it is detected that its a false reading
    // When the next directive is seen, then the content block in the previous field needs to be truncated
    mode = .find_directive;
    inline for (str, 0..) |c, index| {
        // @compileLog(c, index);
        switch (mode) {
            .find_directive => {
                switch (c) {
                    '.' => {
                        maybe_directive_start = index;
                        mode = .reading_directive_name;
                        // @compileLog("maybe new directive at", maybe_directive_start);
                    },
                    ' ', '\t', '\n' => {}, // eat whitespace
                    else => mode = .content_line,
                }
            },
            .reading_directive_name => {
                switch (c) {
                    '\n' => {
                        // found a new directive - we need to patch the value of the previous content then
                        directive_start = maybe_directive_start;
                        if (field_num > 1) {
                            // @compileLog("patching", field_num - 1, content_start, directive_start - 1);
                            var adjusted_len = directive_start - content_start;
                            // fields[field_num - 1].type = *const [adjusted_len]u8;
                            fields[field_num - 1].type = [adjusted_len]u8;
                            // fields[field_num - 1].type = [adjusted_len]u8;
                            // @compileLog("patched previous to", fields[field_num - 1]);
                        }
                        const dname = str[directive_start + 1 .. index];
                        const dlen = str.len - index;
                        content_start = index + 1;
                        if (content_start < str.len) {
                            fields[field_num] = .{
                                .name = dname,
                                // .type = *const [dlen]u8,
                                .type = [dlen]u8,
                                .default_value = str[content_start..],
                                // .default_value = @ptrCast(&str[content_start..]),
                                // .default_value = @ptrCast(&str[0..]),
                                // .default_value = all.default_value,
                                // .default_value = @ptrCast(&"Hello World"),
                                // .default_value = @ptrCast(&str[content_start..]),
                                .is_comptime = true,
                                .alignment = 1,
                            };
                            // @compileLog("field", field_num, fields[field_num]);
                        }
                        field_num += 1;
                        mode = .content_line;
                    },
                    ' ', '\t', '.', '-', '{', '}', '[', ']', ':' => { // invalid chars for directive name
                        mode = .content_line;
                        maybe_directive_start = directive_start;
                    },
                    else => {},
                }
            },
            .content_line => { // just eat the rest of the line till the next line
                switch (c) {
                    '\n' => mode = .find_directive,
                    else => {},
                }
            },
        }
    }

    // @compileLog("fields", fields);

    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = &fields,
            .decls = decls,
            .is_tuple = false,
        },
    });
}

test "manually defining a struct" {
    var out = std.io.getStdErr().writer();
    try out.writeAll("\n------------------manually defined struct----------------------\n");

    const Thing = struct {
        comptime name: *const [10:0]u8 = "Name: {s}\n",
        comptime address: *const [10:0]u8 = "Addr: {s}\n",
    };

    inline for (@typeInfo(Thing).Struct.fields, 0..) |f, i| {
        try out.print("Thing field={} name={s} type={} is_comptime={} default_value={?}\n", .{ i, f.name, f.type, f.is_comptime, f.default_value });
    }

    var thing = Thing{};
    try out.print("typeof thing.name is {}\n", .{@TypeOf(thing.name)});
    try out.print(thing.name, .{"Rupert Montgomery"});
    try out.print(thing.address, .{"21 Main Street"});
}

fn GenerateType() type {
    comptime var fields: [2]std.builtin.Type.StructField = undefined;
    comptime var decls = &[_]std.builtin.Type.Declaration{};
    fields[0] = .{
        .name = "name",
        .type = *const [10]u8,
        .is_comptime = true,
        .alignment = 0,
        .default_value = @ptrCast(&"Name: {s}\n"),
    };
    fields[1] = .{
        .name = "address",
        .type = *const [10]u8,
        .is_comptime = true,
        .alignment = 0,
        .default_value = @ptrCast(&"Addr: {s}\n"),
    };
    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = &fields,
            .decls = decls,
            .is_tuple = false,
        },
    });
}

test "generated struct" {
    var out = std.io.getStdErr().writer();
    try out.writeAll("\n------------------generated struct----------------------\n");

    comptime var Thing = GenerateType();

    inline for (@typeInfo(Thing).Struct.fields, 0..) |f, i| {
        try out.print("Thing field={} name={s} type={} is_comptime={} default_value={?}\n", .{ i, f.name, f.type, f.is_comptime, f.default_value });
    }

    comptime var thing = Thing{};
    try out.print("typeof thing.name is {}\n", .{@TypeOf(thing.name)});
    try out.print(thing.name, .{"Rupert Montgomery"});
    try out.print(thing.address, .{"21 Main Street"});
}

test "template with no segments" {
    var out = std.io.getStdErr().writer();
    try out.writeAll("\n-----------------template with no segments----------------------\n");
    const t = Template("testdata/all.txt");
    inline for (@typeInfo(t).Struct.fields, 0..) |f, i| {
        try out.print("all.txt field={} name={s} type={} is_comptime={} default_value={?}\n", .{ i, f.name, f.type, f.is_comptime, f.default_value });
    }
    comptime var data = Template("testdata/all.txt"){};
    try out.print("typeof data.all is {}\n", .{@TypeOf(data.all)});
    try out.print(data.all, .{});
    try std.testing.expectEqual(57, data.all.len);
}

test "template with multiple segments" {
    var out = std.io.getStdErr().writer();
    try out.writeAll("\n-----------------template with multiple segments----------------------\n");
    comptime var t = Template("testdata/foobar.txt");
    inline for (@typeInfo(t).Struct.fields, 0..) |f, i| {
        std.debug.print("foobar.txt has field {} name {s} type {}'\n", .{ i, f.name, f.type });
    }
    comptime var data = Template("testdata/foobar.txt"){};

    try out.print("Whole contents of foobar.txt is:\n---------------\n{s}\n---------------\n", .{data.all});
    try out.print("\nfoo: '{s}'\n", .{data.foo});
    try out.print("\nbar: '{s}'\n", .{data.bar});
    try std.testing.expectEqual(52, data.all.len);
    try std.testing.expectEqual(19, data.foo.len);
    try std.testing.expectEqual(24, data.bar.len);
}
