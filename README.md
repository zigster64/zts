# ZTS

Zig Templates made Simple

A utility lib that uses Zig's comptime power to make a dead simple and pretty efficient templating engine.


Its all done at comptime, so there is no runtime overhead for parsing or allocation, no code generation.

Is all just zig end-to-end, so there is no funky new templating syntax to apply either.

Lets have a look ...


## Very Basic Example

Lets say you have a Template file `foobar.txt` that looks like this :

```
.foo
I prefer daytime
.bar
I like the nighttime
```

Then in your zig code, you can create a new struct type from that text file, which has fields as defined in the text file above, filled in the static strings as defined in the file between the .directives.

```
const zts = @import("zts");

const my_foobar = zts.embed("foobar.txt"){}; // this returns an instance of a new foobar struct type

std.debug.print("{s}\n", my_foobar.foo);
std.debug.print("{s}\n", my_foobar.bar);
```

Thats really all there is to it.

If you mess up your template file, or your zig code ... Zig will pick that up at compile time, and throw an error about missing struct fields.


## A more common HTML templating example

Lets define a typical HTML file, with segments defined, and add some places where we can print 
Using the HTML template that looks something like this :
```html
.details
<div>
    <h1>Customer</h1>
    <p>Name: {[name]:s}</p>
    <p>Address: {[address]:s}</p>
    <p>Phone: {[phone]:s}</p>

    .invoice_table_start
    <h2>Invoices</h2>
    <table>
        <tr>
            <th>Date</th>
            <th>Details</th>
            <th>Amount</th>
        </tr>

        .invoice_row
        <tr>
            <td>{[date]:s}</td>
            <td>{[details]:s}</td>
            <td>{$[amount]}</td>
        </tr>

        .invoice_table_total
        <tr>
            <td></td>
            <td>Total Due:</td>
            <td>$ {[total]}</td>
        </tr>

    </table>
</div>

```

In your zig code :
```
const zts = @import("zts");

// lets use it in a web request handler
fn printCustomerDetails(out: anytype, cust: *CustomerDetails) !void {

    var html = zts.embed("html/customer_details.html"); 
    
    try out.print(html.details, .{
        .name = cust.name,
        .address = cust.address,
        .phone = cust.phone,
    });

    try out.write(html.invoice_table_start);
    var total = 0.0;
    for (cust.invoices) |invoice|  {
        try out.print(html.invoice_row, invoice);
        total += invoice.amount;
    }
    
    try out.write(html.invoice_table_total, .{.total = total});
}
```

Its quite simple - the ZTS templating engine simply splits the input file into segments delimited by .directives

Then using the awesome power of Zig's comptime `fmt.print()` - you can pass structs to the print statement, and then use the `{[fieldname]:format}` syntax to derefence fields out of the struct, and apply standard formatting to them.



