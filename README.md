# ZTS

# Zig Templates made Simple (ZTS)

![zts](https://github.com/zigster64/zts/blob/main/docs/zts.jpg?raw=true)

A utility lib that uses Zig's comptime power to make a dead simple and pretty efficient text templating engine.

Its all done at comptime, so there is no runtime overhead for parsing or allocation, no code generation.

There is no funky new templating syntax to apply either, its just Zig, and nothing but Zig.

As a HTML templating util, this covers a lot of bases, and provides a pretty sane DX, with compile time template validation, and the ability to apply fine grained format control to structured fields.

Lets have a look ...

## Differences vs other Zig Templating tools

There are a number of excellent template engine tools for Zig, which use the traditional approach of passing a template + some declarations
to a template library, which then controls the output of the data through the template.

https://github.com/batiati/mustache-zig  (an implementation of Mustache for Zig)

https://github.com/MasterQ32/ZTT (a text template tool that uses code generation)

ZTS uses an inversion of this common templating approach, by passing sections of your data through sections of the template, whilst
keeping the control of this flow strictly inside your Zig code at all times.

ZTS also uses Zig's standard `print` formatting to transform data through the template, so there is no additional DSL or formatting rules to learn.

The other MAJOR difference is that ZTS is strictly comptime only templating. This brings a lot of benefits, such as :
- Simplicity. There is just _less_ going on
- Zero runtime parsing overhead
- Runtime speed
- Thorough compile time checking of both template and parameters
- Mismatches between templates and logic are very unlikely to get past compilation, and raise their ugly heads at runtime

And some negatives too, such as:
- Build times do slow down due to comptime processing
- Complete inability to have dynamically generated templates
- Complete inability to modify the template at runtime
- You can do some dynamic processing, and abuse the templates to some extent, but the pain level increases very quickly because of Zig comptime restrictions

Choices are good. Its up to you to work out which approach best suits your project.

## ZTS - Very Basic Example

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
try out.print("foo says - {s}\n", zts.s(my_foobar, "foo"));
try out.print("bar says - {s}\n", zts.s(my_foobar, "bar"));

```

produces the output 
```
foo says - I prefer daytime

bar says - I like the nighttime

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

Putting `zts.s(data, section_name)` everywhere is a bit verbose, and gets a bit messy very quickly. 

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
try zts.printSection(data, "bar", .{"nighttime"}, out);

```

Because everything is happening at comptime, if your template file and your Zig code get out of sync due to ongoing changes,
nothing to fear ... Zig will pick that up at compile time, and throw an error about missing sections in your templates, as 
well as the standard compile errors about parameters not matching the expected fields in the template.

for example, if you add this to the code above :

```zig
try zts.printSection(data, "other", .{}, out);
```

This will throw a compile error saying that there is no section labelled `other` in the template.

If the template gets modified - say change the label `.foo` to `.fooz` in the text file ... then that will also cause
a compile error in the Zig code, saying that "foo" doesnt exist in the template anymore.

If the template changes again, say ... change the `.foo` contents to `I like {d}` ... then this will also cause a compile
error in the Zig code, saying that the string parameter "daytime" does not match format "{d}" in the template.

There is no great magic here, its just the power of Zig comptime, as it is actively parsing the text templates at compile time,
and using the built in Zig `print` formatting which also evaluates at compile time.

## ZTS runtime / non-comptime helper functions

If you want to pass data through template segments using the built in Zig `print` functions on the writer, then everything must be comptime.

There are no exceptions to this, its just the way that Zig `print` works.

If your template segments DO NOT have print formatting, do not need argument processing, and are just blocks of text,
then you can use the `write` variant helper functions that ZTS provides.

```zig
try zts.writeHeader(data, out);
try zts.writeSection(data, section, out);
```

There is also a `lookup()` function that takes runtime / dynamic labels, and returns a non-comptime string of the section ... or `null` if not found.
Its a runtime version of the `s()` function, that can be used with dynamic labels.

You can ONLY use the return data from `lookup()` in a non-comptime context though.


example:
```zig

// you can do some fancy dynamic processing here
const dynamic_template_section = zts.lookup(data, os.getenv("PLANET").?);
if (dynamic_template_section == null) {
   std.debug.print("Sorry, cannot find a section for the planet you are on");
   return;
}
try out.writeAll(dynamic_template_section);

// or you can do this using the write helper functions
try zts.writeSection(data, os.getenv("PLANET"), out);  

// but you cant do this, because print NEEDS comptime values only, and lookup is a runtime variant
try out.print(dynamic_template_section, .{customer_details});  // <<-- compile error ! dynamic_template_section is not comptime known

// and you cant do this either, because s() demands comptime params too
const printable_dynamic_section = zts.s(data, os.getenv("PLANET").?);  // <<-- compile error !  unable to resovle comptime value
```

Comptime restrictions can be a pain.

ZTS `lookup()`, `writeHeader()`, and `writeSection()` might be able to help you out if you need to do some dynamic processing .. or it might not, 
depending on how deep a hole of meta programming you are in.


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

As far as "template engines" go - ZTS is just like a fancy table of strings that you have to drive yourself manually.

This is an inversion of how templating libraries usually work ... where your code passes data to the template engine, which then drives
the flow of the logic to produce the output.

The traditional approach tends to get messy when you want to inject additional logic into the template generation, over and above simple range statements.

Other approaches, such as JSX, employ a variety of character codes enabling you to jump in and out of Javascript inside the template.

or Go templates, which have their own go-like DSL, and the ability to pass a map of function pointers that the template can callback into.

See https://pkg.go.dev/html/template for details of Go HTML templating.

There is also the Mustache standard, which offers an array iterator, and lambdas, and rendering of partials amongst other things.

These are all great of course, but they also delegate the control away from your program, and into a DSL like environment that inevitably employs
some magic to get the job done.

In some instances, it may be more powerful (as well as simpler), to just drive all the logic directly and imperatively from your own code instead.
In my subjective opinion, this direct and imperative approach is more in keeping with the Zen of Zig. YMMV.

If you want the traditional approach, whilst using Zig, have a look at 

https://github.com/batiati/mustache-zig

with examples of mustache-zig used in the Zap (web server) project here :

https://github.com/zigzap/zap/blob/master/examples/mustache/mustache.zig

There are some examples of ZTS used with the http.zig library here :

https://github.com/zigster64/zig-zag-zoe


## Selectively print sections from the template

In the traditional Template-Driven approach, this is normally done by adding syntax to the template such as
```
Hey There
  You owe us some money !

  Here is the proof ...

{{if language .eq "deutsch"}}
  Geschäftsbedingungen
  Zahlung 7 Tagen netto
{{else}}
  Terms and conditons
  Payment Nett 7 days
{{endif}}
```

But we dont need to add any control flow inside the template in some non-Zig templating language ... we can just do it from the Zig code
because the whole "template" is nothing more than a map of section tags to blocks of text.

You dont even need to print them all !

Example:
```
Hey There
  You owe us some money !

  Here is the proof ...

.terms_en
  Terms and conditons
  Payment Nett 7 days
.terms_de
  Geschäftsbedingungen
  Zahlung 7 Tagen netto
.terms_es
  Términos y condiciones
  Pago neto 7 días
.terms_pt
  Termos e Condições
  Pagamento líquido em 7 dias
.terms_fr
  Termes et conditions
  Paiement net 7 jours
.terms_hi
  नियम और शर्तें
  भुगतान नेट 7 दिन
.terms_jp
  利用規約
  次の7日でお支払い
```

```zig

// dynamically create the label at runtime, based on the LANG env var
// restriction here is that because the section label is dynamic, it cant be comptime
// ... and therefore cant be used with the print variants

try terms_section = std.fmt.allocPrint(allocator, "terms_{s}", std.os.getenv("LANG").?[0..2]);
defer allocator.free(section);

try zts.writeHeader(data, out);
try zts.writeSection(data, terms_section, out);
}
```

(see example in test cases inside the code in zts.zig)

Or we can even mix up the order of sections in the output depending on some variable :

```zig
if (is_northern_hemisphere) try zts.writeHeader(data, out);
try zts.writeSection(data, terms_section, out);
if (is_southern_hemisphere) try zts.writeHeader(data, out);
```

So for our US and EU customers, they get the Notice header followed by the terms and conditions.

For our AU, NZ, and Sth American customers, because they are upside down, they get the terms and conditions first followed by the Notice header.

... not sure how you could even do that in a normal templating flow ?

So again, its not for everyone, but there are definitely some cases where its just simpler and more powerful to keep the control inside your
Zig code rather than a templating engine.


# Section Declaration Syntax

In the template examples above, sections in the template are simply denoted by a line that has a `.directive` and nothing else.

Syntactically, the `.directive` in the template must obey these rules :

- Can start with any amount of leading whitespace
- Begins with a `.` character
- Contains just the directive word with no whitespace, and no templated content
- Directive name cannot contain special characters [] {} - : \t
- Is a complete line, terminated by a `\n` 

Any lines that do not obey all of the above rules are considered as content, and not a directive.


## Content that occurs before the first directive

All content that occurs before the first directive is considered to be the "header" of the document.

Example:
```html
<div>
   Everything in here is leading content

   .details
   <div>... some details in here</div>
   .end_details

   ... more content
</div>
```

Or you can use the `printHeader(data, args, out)` helper function to print out this header segment.
```zig
const data = @embedFile("foobar.txt");
try zts.printHeader(data, .{}, out);

// or the write variant with no extra parameters 
try zts.writeHeader(data, out);
```

You can access this header section using the `s()` function, and passing `null` as the section name.

```zig
const data = @embedFile("foobar.txt");
const header_content = zts.s(data, null);

// or use lookup for the runtime variant
const header_content = zts.lookp(data, null); 
```

