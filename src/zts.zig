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
    @setEvalBranchQuota(500000);
    const decls = &[_]std.builtin.Type.Declaration{};

    // empty strings, or strings that dont start with a .directive - just map the whole string to .all and return early
    if (str.len < 1 or str[0] != '.') {
        // @compileLog("file is not a template");
        var fields: [1]std.builtin.Type.StructField = undefined;
        fields[0] = .{
            .name = "all",
            .type = [str.len]u8,
            .is_comptime = true,
            .alignment = 0,
            .default_value = str[0..],
        };
        // @compileLog("non-template using fields", fields);
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
    var maybe_directive_start = 0;
    var content_start = 0;
    var field_num = 1;

    // so now we need to loop through the whole parser a 2nd time to get the field details
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
                    ' ', '\t', '.', '{', '}', '[', ']', ':' => { // invalid chars for directive name
                        mode = .content_line;
                        maybe_directive_start = directive_start;
                    },
                    else => {},
                }
            },
            .content_line => { // just eat the rest of the line till the next CR
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

test "all" {
    var out = std.io.getStdErr().writer();
    const t = embed("testdata/all.txt");
    inline for (@typeInfo(t).Struct.fields, 0..) |f, i| {
        try out.print("all.txt has field {} name {s} type {}\n", .{ i, f.name, f.type });
    }
    const data = t{};
    try out.print("Whole contents of all.txt is:\n{s}\n", .{data.all});
    try std.testing.expectEqual(57, data.all.len);
}

test "foobar" {
    var out = std.io.getStdErr().writer();
    const t = embed("testdata/foobar.txt");
    inline for (@typeInfo(t).Struct.fields, 0..) |f, i| {
        std.debug.print("foobar.txt has field {} name {s} type {}'\n", .{ i, f.name, f.type });
    }
    const data = t{};

    try out.print("Whole contents of foobar.txt is:\n---------------\n{s}\n---------------\n", .{data.all});
    try out.print("\nfoo: '{s}'\n", .{data.foo});
    try out.print("\nbar: '{s}'\n", .{data.bar});
    try std.testing.expectEqual(52, data.all.len);
    try std.testing.expectEqual(19, data.foo.len);
    try std.testing.expectEqual(24, data.bar.len);
}

test "customer_details" {
    // create some test data to push through the HTML report
    const Invoice = struct {
        date: []const u8,
        details: []const u8,
        amount: u64,
    };

    const Customer = struct {
        name: []const u8,
        address: []const u8,
        credit: u64,
        invoices: []const Invoice,
    };

    const cust = Customer{
        .name = "Bill Smith",
        .address = "21 Main Street",
        .credit = 12345,
        .invoices = &[_]Invoice{
            .{ .date = "12 Sep 2023", .details = "New Hoodie", .amount = 9900 },
            .{ .date = "24 Sep 2023", .details = "2 Hotdogs with Cheese and Sauce", .amount = 1100 },
            .{ .date = "14 Oct 2023", .details = "Milkshake", .amount = 30 },
        },
    };

    var out = std.io.getStdErr().writer();
    const html_t = embed("testdata/customer_details.html");

    inline for (@typeInfo(html_t).Struct.fields, 0..) |f, i| {
        try out.print("html has field {} name {s} type {}\n", .{ i, f.name, f.type });
    }

    const html = html_t{};

    try out.writeAll("------ details template -------\n");
    try out.print("{s}", .{html.details});
    try out.writeAll("------ invoice_table template -------\n");
    try out.print("{s}", .{html.invoice_table});
    try out.writeAll("------ invoice_row template -------\n");
    try out.print("{s}", .{html.invoice_row});
    try out.writeAll("------ invoice_row total -------\n");
    try out.print("{s}", .{html.invoice_total});
    try out.writeAll("\n-------------------------------\n");
    try out.print(&html.details, .{
        .name = cust.name,
        .address = cust.address,
        .credit = cust.credit,
    });
    try out.writeAll("----------------------\n");

    // try out.print(&html.details, cust);
    // try out.writeAll(&html.invoice_table_start);
    // var total: f32 = 0;
    // for (cust.invoices) |invoice| {
    // try out.print(&html.invoice_row, invoice);
    // total += invoice.amount;
    // }

    // try out.print(&html.invoice_table_total, .{ .total = total });
}
