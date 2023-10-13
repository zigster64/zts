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

## Difference to other templating tools




## Very Basic Example

Lets say you have a Template file `foobar.txt` that looks like this :

```
.foo
I prefer daytime
.bar
I like the nighttime
```

Then in your zig code, just embed that file, and then use the `zts.s(data, section_name)` function to return the appropriate section out of the data.

```zig
const zts = @import("zts");

const out = std.io.getStdOut().writer();

const data = @embedFile("foobar.txt");
try out.print("{s}\n", zts.s(my_foobar, "foo"));
try out.print("{s}\n", zts.s(my_foobar, "bar"));

```

Thats really all there is to it. Its basically splitting the input into sections delimited by named tags in the input text.

## The contents of data Sections are comptime known

The data returned from `s(data, section_name)` is comptime known ... which means that it can in turn be passed to Zig standard print functions 
as a formatting string.

```
.foo
I like {s}
.bar
I prefer {s}
```

```zig

const data = @embedFile("foobar.txt");
try out.print(zts.s(data, "foo"), .{"daytime"});
try out.print(zts.s(data, "bar"), .{"nighttime"});

```

## ZTS print helper functions

Use of the `s(data, section_name)` function is provided as a low-level utility.

Putting `zts.s(data, section_name)` name everywhere is a bit verbose, and gets a bit messy very quickly. 

ZTS provides helper functions that make it easier to print.


```
.foo
I like {s}
.bar
I prefer {s}
```

```zig

const data = @embedFile("foobar.txt");
try zts.printSection(data, "foo", .{"daytime"}, out);
try zts.printSection(data, "bar", .{"daytime"}, out);

```

Because everything is happening at comptime, ff your template file and your Zig code get out of sync due to ongoing changes,
nothing to fear ... Zig will pick that up at compile time, and throw an error about missing sections in your templates, as 
well as the standard compile errors about parameters not matching the expected fields in the template.

for example, if you add this to the code above :

```zig
try zts.printSection(data, "other", .{}, out);
```

This will throw a compile error saying that there is no section labelled `other` in the template.

## A more common HTML templating example

Lets define a typical HTML file, with template segments defined, and add some places where we can print structured data that we pass through the template.

The HTML template looks like this :

```html
<div>
  <h1>Financial Statement Page</h1>

    .customer_details
    <h1>Customer</h1>
    <p>Name: {[name]:s}</p>
    <p>Address: {[address]:s}</p>
    <p>Credit Limit: $ {[credit]:.2}</p>

    .invoice_table
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
            <td>$ {[amount]:.2}</td>
        </tr>

        .invoice_table_total
        <tr>
            <td></td>
            <td>Total Due:</td>
            <td>$ {[total]:.2}</td>
        </tr>

    </table>
</div>

```

And the Zig code to print data through that template looks like this :
```zig
fn printCustomerDetails(out: anytype, cust: *CustomerDetails) !void {

  var data = @embedFile("html/financial_statement.html");
   
   try zts.printHeader(data, .{}, out);
   try zts.printSection(data, "customer_details", .{
        .name = cust.name,
        .address = cust.address,
        .credit = cust.credit,
   });

   try zts.printSection(data, "invoice_table", .{}, out);
    for (cust.invoices) |invoice|  {
      try zts.printSection(data, "invoice_row", .{
          .date = invoice.date,
          .details = invoice.details,
          .amount = invoice.amount,
        },
      out);
      total += invoice.amount;
    }

    try zts.printSection(data, "invoice_total", .{.total = total}, out);
}
```

## ZTS Templates rely on your Zig code to drive the logic

You will notice that the pattern used here is that the Zig code is completely driving the flow of logic, and the "template" only serves 
to provide a repository of static strings that can be looked up, and delivered at comptime.

As far as "template engines" go - ZTS is just a fancy hashMap of strings that you have to drive yourself manually.

This is an inversion of how templating libraries usually work ... where your code passes data to the template engine, which then drives
the flow of the logic to produce the output.

The traditional approach tends to get messy when you want to inject additional logic into the template generation, over and above simple range statements.

Other approaches, such as JSX, employ a variety of character codes enable you to jump in and out of Javascript inside the template.

or Go templates, which have their own go-like DSL, and the ability to pass a map of function pointers that the template can then callback into.

There is also the Mustache standard, which offers an array iterator, and lambdas, and rendering of partials amongst other things.

These are all great of course, but they also delegate the control away from your program, and into a DSL like environment that inevitably employs
some magic to get the job done.

In some instances, it may be more powerful (as well as simpler), to just drive all the logic directly and imperatively from your own code instead.


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
var data = zts.template("foobar.txt"){}
std.debug.print("I am foobar, and I only have 1 field  {s}\n", .{data.all});
```

NOTE that segmented data also has the `.all` field, which contains the complete template contents, including any `.directives`


## Segment Declaration Syntax

In the template examples above, segments in the template (and therefore fields in the comptime generated struct) are simply denoted by a line that has a `.directive` and nothing else.

Syntactically, the `.directive` in the template must obey these rules :

- Can start with any amount of leading whitespace
- Begins with a `.` character
- Contains just the directive word with no whitespace, and no templated content
- Directive name cannot contain special characters [] {} - : \t
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


