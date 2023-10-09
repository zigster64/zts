# ZTS

Currently published under the `DTT` Licence (Dont Touch This), because its not baked yet !!

Please wait for v0.0.1

# Zig Templates made Simple (ZTS)

![zts](https://github.com/zigster64/zts/blob/main/docs/zts.jpg?raw=true)

A utility lib that uses Zig's comptime power to make a dead simple and pretty efficient text templating engine.

Its all done at comptime, so there is no runtime overhead for parsing or allocation, no code generation.

There is no funky new templating syntax to apply either, its just Zig, and nothing but Zig.

As a HTML templating util, this covers a lot of bases, and provides a pretty sane DX, with compile time template validation, and the ability to apply fine grained format control to structured fields.

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

If your template file and your Zig code get out of sync due to ongoing changes, nothing to fear ... Zig will pick that up at compile time, and throw an error about missing struct fields, rather than discovering a template bug at runtime.

for example, if you add this to the code above :

```zig
std.debug.print("{s}\n", my_foobar.header); // compile error as the .header directive doesnt exist in the template file !
```

In addition to having fields `.foo` and `.bar`, the templated type also has an automatic field named `.all` which contains the entire content, stripped of directives.

eg: 
```zig
std.debug.print("{s}\n", .{my_foobar.all});
```

will output :
```
I prefer daytime
I like the nighttime
```

## A more common HTML templating example

Lets define a typical HTML file, with template segments defined, and add some places where we can print structured data that we pass through the template.

The HTML template looks like this :

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

And the Zig code to print through the template looks like this :
```zig
const zts = @import("zts");

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

## Segmented vs Non-Segmented Templates

A template is considered to be segmented into fields IF the very first character in the file is `.` AND the first line contains no whitespaces.

In other words - the first line is a valid template `.directive`

If the file is seen to be segmented, then the returned struct will contain fields matching each segment.

If the file is NOT segmented, then the returned struct will contain only 1 field, named `all`, which contains the entire template.

example template `foobar.txt`

```
Foo prefers the daytime
Bar prefers the nighttime
```

Zig code that uses the template
```zig
var data = zts.embed("foobar.txt"){}
std.debug.print("I am foobar, and I only have 1 field  {s}\n", .{data.all});
```

NOTE that segmented data also has the `.all` field, which contains the complete template contents, stripped of `.directives`


## Segment Declaration Syntax

In the template examples above, segments in the template (and therefore fields in the comptime generated struct) are simply denoted by a line that has a `.directive` and nothing else.

Syntactically, the `.directive` in the template must obey these rules :

- Can start with any amount of leading whitespace
- Begins with a `.` character
- Contains just the directive word with no whitespace, and no templated content
- Is a complete line, terminated by a `CR` or `LF`

Any lines that do not obey all of the above rules are considered as content, and not a directive.

Even then, things can get messy if the content that you are wrapping in a template happens to also happens to include text that obeys these rules.

(TODO - add an alternative directive as descibed here)

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


