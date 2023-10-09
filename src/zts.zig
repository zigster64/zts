const std = @import("std");

fn embed(comptime path: []const u8) type {
    return template(@embedFile(path));
}

const Mode = enum {
    waiting_for_start_directive,
    reading_directive_name,
    content_line,
};

fn template(comptime str: []const u8) type {
    const decls = &[_]std.builtin.Type.Declaration{};

    // empty strings, or strings that dont start with a template segment - just map the whole string to .all
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
    var mode: Mode = .waiting_for_start_directive;
    var num_fields = 0;
    inline for (str) |c| {
        switch (mode) {
            .waiting_for_start_directive => {
                switch (c) {
                    '.' => {
                        mode = .reading_directive_name;
                    },
                    ' ', '\n' => {
                        // skip leading whitespace
                    },
                    else => {
                        mode = .content_line;
                    },
                }
            },
            .reading_directive_name => {
                switch (c) {
                    '\n' => {
                        // got the end of a directive !
                        num_fields += 1;
                        mode = .waiting_for_start_directive;
                    },
                    ' ' => {
                        mode = .content_line;
                    },
                    else => {
                        // skip this byte
                    },
                }
            },
            .content_line => {
                switch (c) {
                    '\n' => {
                        mode = .waiting_for_start_directive;
                    },
                    else => {
                        // skip this byte, we are still reading a line
                    },
                }
            },
        }
    }

    @compileLog("num_fields =", num_fields);

    if (num_fields < 1) {
        @compileError("No fields found");
    }

    // now we know how many fields there should be
    var fields: [num_fields + 1]std.builtin.Type.StructField = undefined;

    // inject the all value
    fields[0] = .{
        .name = "all",
        .type = [str.len]u8,
        .is_comptime = true,
        .alignment = 0,
        .default_value = str[0..],
    };

    var directive_start = 0;
    var start = 0;
    _ = start;
    var end = 0;
    _ = end;
    var field_num = 1;

    // so now we need to loop through the whole parser a 2nd time to get the field details
    mode = .waiting_for_start_directive;
    inline for (str, 0..) |c, index| {
        switch (mode) {
            .waiting_for_start_directive => {
                switch (c) {
                    '.' => {
                        directive_start = index;
                        mode = .reading_directive_name;
                    },
                    ' ', '\n' => {
                        // skip leading whitespace
                    },
                    else => {
                        mode = .content_line;
                    },
                }
            },
            .reading_directive_name => {
                switch (c) {
                    '\n' => {
                        const dname = str[directive_start + 1 .. index - 1];
                        const dlen = index - directive_start - 1;
                        @compileLog("field", field_num, "has name", dname, "of len", dlen);
                        // got the end of a directive !
                        fields[field_num] = .{
                            .name = dname,
                            .type = [dlen]u8,
                            .is_comptime = true,
                            .alignment = 0,
                            .default_value = str[index + 1 ..], // and then we have to truncate this value when we hit the next directive
                        };
                        num_fields += 1;
                        mode = .waiting_for_start_directive;
                    },
                    ' ' => {
                        mode = .content_line;
                    },
                    else => {
                        // skip this byte
                    },
                }
            },
            .content_line => {
                switch (c) {
                    '\n' => {
                        mode = .waiting_for_start_directive;
                    },
                    else => {
                        // skip this byte, we are still reading a line
                    },
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

test "all text" {
    const t = embed("testdata/all.input.txt");
    inline for (@typeInfo(t).Struct.fields, 0..) |f, i| {
        std.debug.print("all.txt has field {} name {s} type {}\n", .{ i, f.name, f.type });
    }
    const data = t{};
    std.debug.print("Whole contents of all.txt is:\n{s}\n", .{data.all});
    // try std.testing.expectEqualStrings(@embedFile("testdata/all.output.txt"), &data.all);
}

test "foo bar" {
    const t = embed("testdata/foobar.input.txt");
    inline for (@typeInfo(t).Struct.fields, 0..) |f, i| {
        std.debug.print("foobar.txt has field {} name {s} type {}\n", .{ i, f.name, f.type });
    }
    const data = t{};
    _ = data;
    // std.debug.print("Whole contents of foobar.txt is:\n{s}\n", .{data.all});
    // try std.testing.expectEqualStrings(@embedFile("testdata/foobar.all.output.txt"), &data.all);
}
