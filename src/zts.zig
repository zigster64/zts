const std = @import("std");

fn embed(comptime path: []const u8) type {
    return template(@embedFile(path));
}

fn template(comptime str: []const u8) type {
    var start = 0;
    _ = start;
    var end = 0;
    _ = end;
    var field_num = 0;
    _ = field_num;
    var num_fields = 0;
    _ = num_fields;
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

    var fields: [0]std.builtin.Type.StructField = undefined;
    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = &fields,
            .decls = decls,
            .is_tuple = false,
        },
    });
}

test "foo bar" {
    // TODO - make these funcs return an instance of the new type
    const a_type = embed("testdata/all.txt");
    inline for (@typeInfo(a_type).Struct.fields, 0..) |f, i| {
        std.debug.print("all.txt has field {} name {s} type {s}\n", .{ i, f.name, f.type });
    }
    // const a = a_type{};
    // std.debug.print("Whole contents of all.txt is:\n{s}\n", .{a.all});
    // try std.testing.expectEqualStrings(@embedFile("testdata/all.txt"), &a.all);
}
