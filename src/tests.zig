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
        .type = *const [10:0]u8,
        .is_comptime = true,
        .alignment = 0,
        .default_value = @ptrCast(&"Name: {s}\n"),
    };
    fields[1] = .{
        .name = "address",
        .type = *const [10:0]u8,
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
    try out.writeAll("The lines below will crash without throwing an error ... so commented out\n");
    try out.print(thing.name, .{"Rupert Montgomery"});
    try out.print(thing.address, .{"21 Main Street"});
}

test "all" {
    var out = std.io.getStdErr().writer();
    try out.writeAll("\n------------------all.txt----------------------\n");
    const t = Template("testdata/all.txt");
    inline for (@typeInfo(t).Struct.fields, 0..) |f, i| {
        try out.print("all.txt field={} name={s} type={} is_comptime={} default_value={?}\n", .{ i, f.name, f.type, f.is_comptime, f.default_value });
    }
    comptime var data = Template("testdata/all.txt"){};
    _ = data;
    // try out.print("typeof data.all is {}\n", .{@TypeOf(data.all)});
    // try out.print(data.all, .{});
    // try out.print("value data.all is:\n{s}\n", .{data.all});
    // try std.testing.expectEqual(57, data.all.len);
}

test "foobar" {
    var out = std.io.getStdErr().writer();
    const t = Template("testdata/foobar.txt");
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

test "edge-phantom-directive" {
    var out = std.io.getStdErr().writer();
    const t = Template("testdata/edge-phantom-directive.txt");

    inline for (@typeInfo(t).Struct.fields, 0..) |f, i| {
        try out.print("type has field {} name {s} type {}\n", .{ i, f.name, f.type });
    }

    const data = t{};
    try std.testing.expectEqual(49, data.header.len);
    try std.testing.expectEqual(179, data.body.len);
    try std.testing.expectEqual(185, data.footer.len);
    try std.testing.expectEqual(63, data.nested_footer.len);
    try out.print("You can see that the body has lots of phantom directives that didnt trick the parser:\n{s}\n", .{data.body});
    try out.print("\nAnd the footer as well:\n{s}\n", .{data.footer});
}

test "customer_details" {
    const customer_data = .{
        .name = "Bill Smith",
        .address = "21 Main Street",
        .credit = 123.45,
        .invoices = .{
            .{ .date = "12 Sep 2023", .details = "New Hoodie", .amount = 99.00 },
            .{ .date = "24 Sep 2023", .details = "2 Hotdogs with Cheese and Sauce", .amount = 11.00 },
            .{ .date = "14 Oct 2023", .details = "Milkshake", .amount = 3.40 },
        },
    };
    _ = customer_data;
    var out = std.io.getStdErr().writer();
    const html_t = Template("testdata/customer_details.html");

    inline for (@typeInfo(html_t).Struct.fields, 0..) |f, i| {
        try out.print("html has field {} name {s} type {}\n", .{ i, f.name, f.type });
    }

    const html = html_t{};

    // do some basic tests on this loaded template
    // these are all fine
    try std.testing.expectEqual(517, html.all.len);

    try out.writeAll("------ details template -------\n");
    try out.print("{s}", .{html.details});
    try std.testing.expectEqual(126, html.details.len);
    try out.writeAll("------ invoice_table template -------\n");
    try out.print("{s}", .{html.invoice_table});
    try std.testing.expectEqual(119, html.invoice_table.len);
    try out.writeAll("------ invoice_row template -------\n");
    try out.print("{s}", .{html.invoice_row});
    try std.testing.expectEqual(109, html.invoice_row.len);
    try out.writeAll("------ invoice_row total -------\n");
    try out.print("{s}", .{html.invoice_total});
    try std.testing.expectEqual(112, html.invoice_total.len);
    try out.writeAll("\n-------------------------------\n");

    // IRL, should be able to use this template and the provided data like this to generate
    // a populated HTML page out of the segments

    // try out.print(&html.details, .{
    //     .name = cust.name,
    //     .address = cust.address,
    //     .credit = cust.credit,
    // });

    // try out.writeAll(&html.invoice_table_start);
    // var total: f32 = 0;

    // for (cust.invoices) |invoice| {
    //     try out.print(&html.invoice_row, invoice);
    //     total += invoice.amount;
    // }

    // try out.print(&html.invoice_table_total, .{ .total = total });
}
