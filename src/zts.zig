const std = @import("std");

const Mode = enum {
    find_directive,
    reading_directive_name,
    content_line,
};

// s will return the section from the data, as a comptime known string
pub fn s(comptime str: []const u8, comptime directive: ?[]const u8) []const u8 {
    comptime var mode: Mode = .find_directive;
    comptime var maybe_directive_start = 0;
    comptime var directive_start = 0;
    comptime var content_start = 0;
    comptime var content_end = 0;
    comptime var last_start_of_line = 0;

    @setEvalBranchQuota(1_000_000);

    inline for (str, 0..) |c, index| {
        switch (mode) {
            .find_directive => {
                switch (c) {
                    '.' => {
                        maybe_directive_start = index;
                        mode = .reading_directive_name;
                        // @compileLog("maybe new directive at", maybe_directive_start);
                    },
                    ' ', '\t' => {}, // eat whitespace
                    '\n' => {
                        last_start_of_line = index + 1;
                    },
                    else => mode = .content_line,
                }
            },
            .reading_directive_name => {
                switch (c) {
                    '\n' => {
                        if (directive == null) {
                            // then content is the first unlabelled block, so we can return now
                            return str[0..last_start_of_line];
                        }
                        if (content_end > 0) {
                            // that really was a directive following our content then, so we now have the content we are looking for
                            content_end = last_start_of_line;
                            return str[content_start..content_end];
                        }
                        // found a new directive - we need to patch the value of the previous content then
                        directive_start = maybe_directive_start;
                        const directive_name = if (str[index - 1] == '\r')
                            str[directive_start + 1 .. index - 1]
                        else
                            str[directive_start + 1 .. index];
                        content_start = index + 1;
                        if (comptime std.mem.eql(u8, directive_name, directive.?)) {
                            content_end = str.len - 1;
                            // @compileLog("found directive in data", directive_name, "starts at", content_start, "runs to", content_end);
                        }
                        last_start_of_line = index + 1;
                        mode = .find_directive;
                    },
                    '\x01'...'\t', '\x0B'...'\x1F', ' '...'/', ':'...'@', '{'...'}', '['...'^', '`' => { // invalid chars for directive name
                        // @compileLog("false alarm scanning directive, back to content", str[maybe_directive_start .. index + 1]);
                        mode = .content_line;
                        maybe_directive_start = directive_start;
                    },
                    else => {},
                }
            },
            .content_line => { // just eat the rest of the line till the next line
                switch (c) {
                    '\n' => {
                        mode = .find_directive;
                        last_start_of_line = index + 1;
                    },
                    else => {},
                }
            },
        }
    }

    if (content_end > 0) {
        return str[content_start .. content_end + 1];
    }

    if (directive == null) {
        return str;
    }

    const directiveNotFound = "Data does not contain any section labelled '" ++ directive.? ++ "'\nMake sure there is a line in your data that start with ." ++ directive.?;
    @compileError(directiveNotFound);
}

// lookup will return the section from the data, as a runtime known string, or null if not found
pub fn lookup(str: []const u8, directive: ?[]const u8) ?[]const u8 {
    var mode: Mode = .find_directive;
    var maybe_directive_start: usize = 0;
    var directive_start: usize = 0;
    var content_start: usize = 0;
    var content_end: usize = 0;
    var last_start_of_line: usize = 0;

    for (str, 0..) |c, index| {
        switch (mode) {
            .find_directive => {
                switch (c) {
                    '.' => {
                        maybe_directive_start = index;
                        mode = .reading_directive_name;
                        // @compileLog("maybe new directive at", maybe_directive_start);
                    },
                    ' ', '\t' => {}, // eat whitespace
                    '\n' => {
                        last_start_of_line = index + 1;
                    },
                    else => mode = .content_line,
                }
            },
            .reading_directive_name => {
                switch (c) {
                    '\n' => {
                        if (directive == null) {
                            // then content is the first unlabelled block, so we can return now
                            return str[0..last_start_of_line];
                        }
                        if (content_end > 0) {
                            // that really was a directive following our content then, so we now have the content we are looking for
                            content_end = last_start_of_line;
                            return str[content_start..content_end];
                        }
                        // found a new directive - we need to patch the value of the previous content then
                        directive_start = maybe_directive_start;
                        const directive_name = if (str[index - 1] == '\r')
                            str[directive_start + 1 .. index - 1]
                        else
                            str[directive_start + 1 .. index];
                        content_start = index + 1;
                        if (std.mem.eql(u8, directive_name, directive.?)) {
                            content_end = str.len - 1;
                            // @compileLog("found directive in data", directive_name, "starts at", content_start, "runs to", content_end);
                        }
                        last_start_of_line = index + 1;
                        mode = .find_directive;
                    },
                    '\x00'...'\t', '\x0B'...'\x1F', ' '...'/', ':'...'@', '{'...'}', '['...'^', '`' => { // invalid chars for directive name
                        // @compileLog("false alarm scanning directive, back to content", str[maybe_directive_start .. index + 1]);
                        mode = .content_line;
                        maybe_directive_start = directive_start;
                    },
                    else => {},
                }
            },
            .content_line => { // just eat the rest of the line till the next line
                switch (c) {
                    '\n' => {
                        mode = .find_directive;
                        last_start_of_line = index + 1;
                    },
                    else => {},
                }
            },
        }
    }

    if (content_end > 0) {
        return str[content_start .. content_end + 1];
    }

    if (directive == null) {
        return str;
    }

    return null;
}

pub fn printHeader(comptime str: []const u8, args: anytype, out: anytype) !void {
    try out.print(comptime s(str, null), args);
}

pub fn print(comptime str: []const u8, comptime section: []const u8, args: anytype, out: anytype) !void {
    try out.print(comptime s(str, section), args);
}

pub fn writeHeader(comptime str: []const u8, out: anytype) !void {
    try out.writeAll(comptime s(str, null));
}

pub fn write(comptime str: []const u8, comptime section: []const u8, out: anytype) !void {
    try out.writeAll(comptime s(str, section));
}

pub fn writeDynamic(str: []const u8, section: []const u8, out: anytype) !void {
    const data = lookup(str, section);
    if (data != null) try out.writeAll(data.?);
}
// ---- {{@enum}} directive support ----

const IdxPair = struct { start: usize, end: usize };

const EnumSegment = union(enum) {
    literal: []const u8,
    enum_self,
    enum_field: IdxPair,
    enum_begin,
    enum_end,
    if_begin_method: IdxPair,
    if_begin_var: IdxPair,
    if_end,
};

fn parseEnumSection(comptime content: []const u8) []const EnumSegment {
    @setEvalBranchQuota(1_000_000);

    const end_pos = comptime std.mem.indexOf(u8, content, "{{/enum}}") orelse
        @compileError("Missing {{/enum}} in section");
    var end = end_pos;
    if (end > 0 and content[end - 1] == '\n') end -= 1;
    if (end > 0 and content[end - 1] == '\r') end -= 1;
    var start: usize = 0;
    if (comptime std.mem.startsWith(u8, content, "{{@enum")) {
        start = (comptime std.mem.indexOfScalar(u8, content, '\n') orelse end) + 1;
    }
    const trimmed = content[start..end];

    comptime var segments: [128]EnumSegment = undefined;
    comptime var seg_count: usize = 0;
    comptime var lit_start: usize = 0;
    comptime var skip: usize = 0;

    inline for (trimmed, 0..) |c, idx| {
        if (skip > 0) {
            if (c == '}' and idx + 1 < trimmed.len and trimmed[idx + 1] == '}') {
                skip -= 1;
                if (skip == 0) lit_start = idx + 2;
            }
            if (c == '{' and idx + 1 < trimmed.len and trimmed[idx + 1] == '{') {
                skip += 1;
            }
            continue;
        }

        if (c == '{' and idx + 1 < trimmed.len and trimmed[idx + 1] == '{') {
            if (idx > lit_start) {
                segments[seg_count] = .{ .literal = trimmed[lit_start..idx] };
                seg_count += 1;
            }
            const inner_start = idx + 2;
            const close = comptime std.mem.indexOfPos(u8, trimmed, inner_start, "}}") orelse
                @compileError("Unclosed '{{' marker");
            const inner = trimmed[inner_start..close];

            if (inner.len == 1 and inner[0] == '.') {
                segments[seg_count] = .enum_self;
            } else if (inner.len > 1 and inner[0] == '.') {
                segments[seg_count] = .{ .enum_field = .{ .start = inner_start + 1, .end = close } };
            } else if (comptime std.mem.startsWith(u8, inner, "@enum")) {
                segments[seg_count] = .enum_begin;
            } else if (comptime std.mem.eql(u8, inner, "/enum")) {
                segments[seg_count] = .enum_end;
            } else if (comptime std.mem.startsWith(u8, inner, "@if .")) {
                segments[seg_count] = .{ .if_begin_method = .{ .start = inner_start + 5, .end = close } };
            } else if (comptime std.mem.startsWith(u8, inner, "@if $.")) {
                segments[seg_count] = .{ .if_begin_var = .{ .start = inner_start + 6, .end = close } };
            } else if (comptime std.mem.eql(u8, inner, "/if")) {
                segments[seg_count] = .if_end;
            } else {
                @compileError("Invalid marker: '{{" ++ inner ++ "}}'");
            }
            seg_count += 1;
            skip = 1;
            lit_start = close + 2;
        }
    }

    if (lit_start < trimmed.len) {
        segments[seg_count] = .{ .literal = trimmed[lit_start..trimmed.len] };
        seg_count += 1;
    }

    return segments[0..seg_count];
}

fn isTruthy(value: anytype) bool {
    const T = @TypeOf(value);
    return switch (@typeInfo(T)) {
        .bool => value,
        .int, .comptime_int => value != 0,
        .float, .comptime_float => value != 0.0,
        .optional => value != null,
        .pointer => |ptr| if (ptr.size == .slice) value.len > 0 else true,
        else => true,
    };
}

fn writeResult(out: anytype, result: anytype) !void {
    const T = @TypeOf(result);
    switch (@typeInfo(T)) {
        .bool => { try out.writeAll(if (result) "true" else "false"); return; },
        .pointer => |ptr| {
            if (ptr.size == .slice and ptr.child == u8) { try out.writeAll(result); return; }
        },
        .int, .comptime_int => { try out.print("{d}", .{result}); return; },
        .float, .comptime_float => { try out.print("{d}", .{result}); return; },
        else => {},
    }
    try out.print("{s}", .{"[unprintable]"});
}

pub fn printEnum(
    comptime tmpl: []const u8,
    comptime section: []const u8,
    comptime EnumType: type,
    context: anytype,
    out: anytype,
) !void {
    if (@typeInfo(EnumType) != .@"enum") {
        @compileError("printEnum requires an enum type, got " ++ @typeName(EnumType));
    }

    const section_prefix = "." ++ section ++ "\n";
    const content = if (comptime std.mem.startsWith(u8, tmpl, section_prefix))
        tmpl[section_prefix.len..]
    else blk: {
        const pos = comptime std.mem.indexOf(u8, tmpl, section_prefix) orelse
            @compileError("Section ." ++ section ++ " not found");
        break :blk tmpl[pos + section_prefix.len ..];
    };
    const segments = comptime parseEnumSection(content);

    inline for (comptime std.meta.fields(EnumType)) |field| {
        const val = comptime @as(EnumType, @enumFromInt(field.value));
        var skip_depth: usize = 0;

        inline for (segments) |seg| {
            switch (seg) {
                .if_end => { if (skip_depth > 0) skip_depth -= 1; },
                .if_begin_method => |idx| {
                    if (comptime blk: {
                        const mn = content[idx.start..idx.end];
                        const method = @field(EnumType, mn);
                        break :blk !isTruthy(@call(.auto, method, .{val}));
                    }) skip_depth += 1;
                },
                .if_begin_var => |idx| {
                    const vn = content[idx.start..idx.end];
                    const fields = comptime @typeInfo(@TypeOf(context)).@"struct".fields;
                    comptime var matched = false;
                    inline for (fields) |ctx_field| {
                        if (comptime std.mem.eql(u8, ctx_field.name, vn)) {
                            if (!isTruthy(@field(context, ctx_field.name))) skip_depth += 1;
                            matched = true;
                        }
                    }
                    if (comptime !matched) @compileError("Context missing field '" ++ vn ++ "'");
                },
                else => {},
            }

            if (skip_depth == 0) {
                switch (seg) {
                    .literal => |lit| try out.writeAll(lit),
                    .enum_self => try out.writeAll(@tagName(val)),
                    .enum_field => |idx| {
                        const mn = content[idx.start..idx.end];
                        const result = comptime blk: {
                            const method = @field(EnumType, mn);
                            break :blk @call(.auto, method, .{val});
                        };
                        try writeResult(out, result);
                    },
                    else => {},
                }
            }
        }
    }
}