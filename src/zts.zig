const std = @import("std");

fn embed(comptime path: []const u8) type {
    return template(@embedFile(path));
}

const Mode = enum {
    find_directive,
    reading_directive_name,
    content_line,
};

fn template(comptime str: []const u8) type {
    const decls = &[_]std.builtin.Type.Declaration{};

    // empty strings, or strings that dont start with a .directive - just map the whole string to .all and return early
    if (str.len < 1 or str[0] != '.') {
        var fields: [1]std.builtin.Type.StructField = undefined;
        fields[0] = .{
            .name = "all",
            .type = [str.len]u8,
            .is_comptime = true,
            .alignment = 0,
            .default_value = str[0..],
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

    // parse the data manually, and work out how many fields we need to define
    var mode: Mode = .find_directive;
    var num_fields = 0;
    inline for (str) |c| {
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
                    ' ' => mode = .content_line,
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
    var fields: [num_fields + 1]std.builtin.Type.StructField = undefined;

    // inject the all values first
    fields[0] = .{
        .name = "all",
        .type = [str.len]u8,
        .is_comptime = true,
        .alignment = 0,
        .default_value = str[0..],
    };

    var directive_start = 0;
    var content_start = 0;
    var field_num = 1;

    // so now we need to loop through the whole parser a 2nd time to get the field details
    mode = .find_directive;
    inline for (str, 0..) |c, index| {
        switch (mode) {
            .find_directive => {
                switch (c) {
                    '.' => {
                        directive_start = index;
                        mode = .reading_directive_name;
                    },
                    ' ', '\n' => {},
                    else => mode = .content_line,
                }
            },
            .reading_directive_name => {
                switch (c) {
                    '\n' => {
                        // found a new directive - we need to patch the value of the previous content then
                        if (field_num > 1) {
                            // @compileLog("patching", field_num - 1, content_start, directive_start - 1);
                            var adjusted_len = directive_start - content_start;
                            fields[field_num - 1].type = [adjusted_len]u8;
                            fields[field_num - 1].default_value = str[content_start .. directive_start - 1];
                            // @compileLog("patched previous to", fields[field_num - 1]);
                        }
                        const dname = str[directive_start + 1 .. index];
                        const dlen = str.len - index;
                        content_start = index + 1;
                        // got the end of a directive !
                        fields[field_num] = .{
                            .name = dname,
                            .type = [dlen]u8,
                            .is_comptime = true,
                            .alignment = 0,
                            .default_value = str[content_start..],
                        };
                        // @compileLog("field", field_num, fields[field_num]);
                        field_num += 1;
                        mode = .content_line;
                    },
                    ' ' => mode = .content_line,
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

    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = &fields,
            .decls = decls,
            .is_tuple = false,
        },
    });
}

test "all" {
    const t = embed("testdata/all.txt");
    inline for (@typeInfo(t).Struct.fields, 0..) |f, i| {
        std.debug.print("all.txt has field {} name {s} type {}\n", .{ i, f.name, f.type });
    }
    const data = t{};
    std.debug.print("Whole contents of all.txt is:\n{s}\n", .{data.all});
    try std.testing.expectEqual(57, data.all.len);
}

test "foobar" {
    const t = embed("testdata/foobar.txt");
    inline for (@typeInfo(t).Struct.fields, 0..) |f, i| {
        std.debug.print("foobar.txt has field {} name {s} type {}'\n", .{ i, f.name, f.type });
    }
    const data = t{};

    std.debug.print("Whole contents of foobar.txt is:\n---------------\n{s}\n---------------\n", .{data.all});
    std.debug.print("\nfoo: '{s}'\n", .{data.foo});
    std.debug.print("\nbar: '{s}'\n", .{data.bar});
    try std.testing.expectEqual(52, data.all.len);
    try std.testing.expectEqual(19, data.foo.len);
    try std.testing.expectEqual(24, data.bar.len);
}
