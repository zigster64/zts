# ZTS

# Zig Templates made Simple (ZTS)

![zts](https://github.com/zigster64/zts/blob/main/docs/zts.jpg?raw=true)

ZTS is a minimalist Zig module that helps you use text templates in a way that is simple, maintainable, and efficient.

Simple:
- Uses Zig like field tags in your template
- Uses Zig `fmt.print` for formatting data 
- No funky new templating syntax, no DSL, no new formatting conventions to learn
- Outputs to Zig `writer` interface. Use it in web server apps !

Maintainable:
- Control of the template logic is done in your Zig code, not delegated to the template engine
- Data passed through the template must be explicitly defined
- There is no magic expansion of data structs that works fine today, and breaks tomorrow as your data model evolves
- Mismatches between your code, your data, and the template are caught at compile time, not runtime

Efficient:
- All template parsing is performed at comptime, no runtime overhead
- Minimal codebase
- There is just _less_ going on compared to full-featured templating engines

Lets have a look ...


## ZTS - Very Basic Example

Lets say you have a Template file `foobar.txt` that looks like this :

```
.foo
I prefer daytime
.bar
I like the nighttime
```

Note the sections `.foo` and `.bar`.  ZTS uses a "Zig like" field syntax for defining the section breaks in the text. 

Then in your zig code, just embed that file, and then use the `zts.s(template, section_name)` function to return the appropriate section out of the data.

```zig
const zts = @import("zts");

const out = std.io.getStdOut().writer();

const tmpl = @embedFile("foobar.txt");
try out.print("foo says - {s}\n", zts.s(tmpl, "foo"));
try out.print("bar says - {s}\n", zts.s(tmpl, "bar"));

```

produces the output 
```
foo says - I prefer daytime

bar says - I like the nighttime

```

Thats really all there is to it. Its basically splitting the input into sections delimited by named tags in the input text.

## The contents of data Sections are comptime known

The data returned from `s(template, section_name)` is comptime known ... which means that it can in turn be passed to Zig standard print functions 
as a formatting string.

```
.foo
I like {s}
.bar
I prefer {s}
```

```zig

const tmpl = @embedFile("foobar.txt");

try out.print(zts.s(tmpl, "foo"), .{"daytime"});
try out.print(zts.s(tmpl, "bar"), .{"nighttime"});

```

## ZTS print helper functions

Use of the `s(tmpl, section_name)` function is provided as a low-level utility.

Putting `zts.s(tmpl, section_name)` everywhere is a bit verbose, and gets a bit messy very quickly. 

ZTS provides helper functions that make it easier to print.


```
.foo
I like {s}
.bar
I prefer {s}
```

```zig

const tmpl = @embedFile("foobar.txt");

try zts.printSection(tmpl, "foo", .{"daytime"}, out);
try zts.printSection(tmpl, "bar", .{"nighttime"}, out);

```

Because everything is happening at comptime, if your template file and your Zig code get out of sync due to ongoing changes,
nothing to fear ... Zig will pick that up at compile time, and throw an error about missing sections in your templates, as 
well as the standard compile errors about parameters not matching the expected fields in the template.

for example, if you add this to the code above :

```zig
try zts.printSection(tmpl, "other", .{}, out);
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
try zts.writeHeader(template, out);
try zts.writeSection(template, section, out);
```

When using `writeSection(template, section, out)` ... if the section is null, or cannot be found in the data, then writeSection will
print nothing. 

There is also a `lookup()` function that takes runtime / dynamic labels, and returns a non-comptime string of the section ... or `null` if not found.
Its a runtime version of the `s()` function, that can be used with dynamic labels.

You can ONLY use the return data from `lookup()` in a non-comptime context though, such as using the data in a `writeAll()` statement.


example:
```zig

// you can do some fancy dynamic processing here
const dynamic_template_section = zts.lookup(tmpl, os.getenv("PLANET").?);
if (dynamic_template_section == null) {
   std.debug.print("Sorry, cannot find a section for the planet you are on");
   return;
}
try out.writeAll(dynamic_template_section);

// or you can do this using the write helper functions
// note that if there is no PLANET env, then nothing is printed
try zts.writeSection(tmpl, os.getenv("PLANET"), out);  

// but you cant do this, because print NEEDS comptime values only, and lookup is a runtime variant
try out.print(dynamic_template_section, .{customer_details});  // <<-- compile error ! dynamic_template_section is not comptime known

// and you cant do this either, because s() demands comptime params too
const printable_dynamic_section = zts.s(tmpl, os.getenv("PLANET").?);  // <<-- compile error !  unable to resovle comptime value
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
    <p>Name:           {[name]:s}</p>
    <p>Address:        {[address]:s}</p>
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
            <td>  {[date]:s}</td>
            <td>  {[details]:s}</td>
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

  var tmpl = @embedFile("html/financial_statement.html");
   
   try zts.writeHeader(tmpl, out);
   try zts.printSection(tmpl, "customer_details", .{
        .name = cust.name,
        .address = cust.address,
        .credit = cust.credit,
   });

   try zts.printSection(tmpl, "invoice_table", .{}, out);
    for (cust.invoices) |invoice|  {
      try zts.printSection(tmpl, "invoice_row", .{
          .date = invoice.date,
          .details = invoice.details,
          .amount = invoice.amount,
        },
      out);
      total += invoice.amount;
    }

    try zts.printSection(tmpl, "invoice_total", .{.total = total}, out);
}
```

So thats all pretty explicit.

Note that we cant do this :

```zig

  var tmpl = @embedFile("html/financial_statement.html");
   
   try zts.writeHeader(tmpl, out);
   
   // explicit parameters defined here
   // try zts.printSection(tmpl, "customer_details", .{
        // .name = cust.name,
        // .address = cust.address,
        // .credit = cust.credit,
   // });

   // this alternative will be a compile error instead
   try zts.printSection(tmpl, "customer_details", cust);
```

Because the struct `CustomerDetails` is not an exact match for the parameters that the "customer_details" section of the template expects,
this will be a compile error.

Yes, its more verbose, but its explicit in the Zen of Zig, and easier to maintain.

By looking at this code only, you can see what parameters the template
expects (without reading the template), and you can see what fields of the
CustomerDetails struct are applied to which template field.

You cant accidentally miss anything, and any future changes to CustomerDetails struct will not 
create any new regressions against the template.


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

There is also Etch :
https://github.com/haze/etch

There are some examples of ZTS used with the http.zig library here :

https://github.com/zigster64/zig-zag-zoe

## Selectively print sections from the template

In the traditional Template-Driven approach, this is normally done by adding syntax to the template such as
```
Hey There {{customer_title}}
  You owe us some money !

  Here is the proof ...

{{if language .eq "de"}}
  Geschäftsbedingungen
  Zahlung 7 Tagen netto
{{elseif language .eq "es"}}
  Términos y condiciones
  Pago neto 7 días
{{elseif }}
  .... etc etc
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
Hey There {s}
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

Looks a bit cleaner, easier to read, and more Ziggy than the previous example.

Code to process this :

```zig

// dynamically create the label at runtime, based on the LANG env var
// restriction here is that because the section label is dynamic, it cant be comptime
// ... and therefore cant be used with the print variants

try terms_section = std.fmt.allocPrint(allocator, "terms_{s}", std.os.getenv("LANG").?[0..2]);
defer allocator.free(section);

try zts.printHeader(tmpl, "Dear Customer", out);
try zts.writeSection(tmpl, terms_section, out);
}
```

(see example in test cases inside the code in zts.zig)

Or we can even mix up the order of sections in the output depending on some variable :

```zig
if (is_northern_hemisphere) try zts.printHeader(tmpl, "Dear Customer", out);
try zts.writeSection(tmpl, terms_section, out);
if (is_southern_hemisphere) try zts.printHeader(tmpl, "Mate", out);
```

So for our US and EU customers, they get the Notice header followed by the terms and conditions.

For our AU, NZ, and Sth American customers, because they are upside down, they get the terms and conditions first followed by the Notice header.

Doing the same thing using a traditional template flow would be possible, but likely to be quite ugly, or involve duplicating sections of 
the template in the original data, wrapped in if statements. 

So again, its not for everyone, but there are definitely some cases where its just simpler and more powerful to keep the control inside your
Zig code rather than a templating engine.


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

Or you can use the `printHeader(template, args, out)` helper function to print out this header segment.
```zig
const tmpl = @embedFile("foobar.txt");
try zts.printHeader(tmpl, .{}, out);

// or the write variant with no extra parameters 
try zts.writeHeader(tmpl, out);
```

You can access this header section using the `s()` function, and passing `null` as the section name.

```zig
const tmpl = @embedFile("foobar.txt");
const header_content = zts.s(tmpl, null);

// or use lookup for the runtime variant
const header_content = zts.lookp(tmpl, null); 
```

# Section Declaration Syntax

In the template examples above, sections in the template are simply denoted by a line that has a `.directive` and nothing else.

The syntax for a `.directive` looks a lot like a Zig field declaration

Syntactically, the `.directive` in the template must obey these rules :

- Can start with any amount of leading whitespace
- Begins with a `.` character
- Contains just the directive word with no whitespace, and no templated content
- Directive name cannot contain special characters [] {} - : \t
- Is a complete line, terminated by a `\n` 

Any lines that do not obey all of the above rules are considered as content, and not a directive.

Example:
```
Things I need to buy this week;
    - milk
    - eggs
    - potatoes
.car_stuff
   - indicator fluid
   - parking meter detector
.computer_stuff
    - more ram
    - more disk
    - more compilers
.notes
   some general notes about things 
   .that need to be purchased
   by the end of the week
```

So that gives us the following sections:
- header (everything from the start up to car_stuff)
- car_stuff
- computer_stuff
- notes

The line in notes beginning with `.that` is not seen as a section, rather its part of the notes content

