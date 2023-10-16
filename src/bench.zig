const std = @import("std");
const zts = @import("zts.zig");

pub fn main() !void {
    std.debug.print("Do 1million runs of passing data through HTML template", .{});
    var out = std.getStdOut().writer(); // pipe this to /dev/null and time it

    const tmpl = @embedFile("testdata/customer_details.html");

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

    try zts.printHeader(tmpl, .{}, out);

    // print the customer details
    try zts.printSection(tmpl, "customer_details", customer, out);

    // print a table of customer invoices
    try zts.printSection(tmpl, "invoice_table", .{}, out);
    var total: f32 = 0.0;
    inline for (invoices) |inv| {
        try zts.printSection(tmpl, "invoice_row", inv, out);
        total += inv.amount;
    }
    try zts.printSection(tmpl, "invoice_total", .{ .total = total }, out);
}
