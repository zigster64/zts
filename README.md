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

```zig
const zts = @import("zts");

const my_foobar = zts.embed("foobar.txt"){}; // this returns an instance of a new foobar struct type

// my_foobar is now an instance of a struct that looks like this
// struct {
//   foo: []const u8 = "I prefer daytime",
//   bar: []const u8 = "I like the nighttime",
// }

std.debug.print("{s}\n", my_foobar.foo);
std.debug.print("{s}\n", my_foobar.bar);

```

Thats really all there is to it.

If you mess up your template file, or your zig code ... Zig will pick that up at compile time, and throw an error about missing struct fields, rather than catching it at runtime.

for example, if you add this to the code above :

```zig
...
std.debug.print("{s}\n", my_foobar.header); // compile error as the .header directive doesnt exist in the template file !
```

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
```zig
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

## Segment Declaration Syntax

In the template examples above, segments in the template (and therefore fields in the comptime generated struct) are simply denoted by a line that has a `.directive` and nothing else.

Syntactically, the `.directive` in the template must obey these rules :

- Can start with any amount of leading whitespace
- Begins with a `.` character
- Contains just the directive word with no whitespace, and no templated content
- Is a complete line, terminated by a `CR` or `LF`

Any lines that do not obey all of the above rules are considered as content, and not a directive.

Even then, things can get messy if the content that you are wrapping in a template happens to also happens to include text that obeys these rules.

In that case, you can use the alternative HTML-esque `<# directive />` syntax to create a templating directive in your file. 


Example :
```html
<# header />

<h1>Hello World</h1>

    <div>Here is some
        .content
    that contains text that 
    could be 
    .mistaken
    for a template directive
    </div>

    <# disclaimer />
    <div>
    But actually its
    .fine
    because we are using the 
    .alternative directive syntax
    in this template instead
    </div>
```


