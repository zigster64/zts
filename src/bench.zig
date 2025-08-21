const std = @import("std");
const zts = @import("zts.zig");

pub fn main() !void {
    std.debug.print("Do 100k runs of passing data through HTML template\n", .{});
    //const out = std.io.getStdOut().writer(); // pipe this to /dev/null and time it
    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const out = &stdout_writer.interface;

    const tmpl = @embedFile("testdata/customer_details.html");

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

    const t1 = std.time.microTimestamp();
    for (0..100_000) |i| {
        _ = i;
        try zts.printHeader(tmpl, .{}, out);

        // print the customer details
        try zts.print(tmpl, "customer_details", customer, out);

        // print a table of customer invoices
        try zts.print(tmpl, "invoice_table", .{}, out);
        var total: f32 = 0.0;
        inline for (invoices) |inv| {
            try zts.print(tmpl, "invoice_row", inv, out);
            total += inv.amount;
        }
        try zts.print(tmpl, "invoice_total", .{ .total = total }, out);
    }
    const t2 = std.time.microTimestamp();
    const te = t2 - t1;
    std.debug.print("Done in {d}us .. or {d}us per template\n", .{ te, @divFloor(te, 100_000) });
}
