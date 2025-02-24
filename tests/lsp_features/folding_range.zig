const std = @import("std");
const zls = @import("zls");
const builtin = @import("builtin");

const tres = @import("tres");

const Context = @import("../context.zig").Context;

const types = zls.types;

const allocator: std.mem.Allocator = std.testing.allocator;

test "foldingRange - empty" {
    try testFoldingRange("", &.{});
}

test "foldingRange - doc comment" {
    try testFoldingRange(
        \\/// hello
        \\/// world
        \\var foo = 5;
    , &.{
        .{ .startLine = 0, .startCharacter = 0, .endLine = 1, .endCharacter = 9, .kind = .comment },
    });
}

test "foldingRange - region" {
    try testFoldingRange(
        \\const foo = 0;
        \\//#region
        \\const bar = 1;
        \\//#endregion
        \\const baz = 2;
    , &.{
        .{ .startLine = 1, .startCharacter = 0, .endLine = 3, .endCharacter = 12, .kind = .region },
    });
    try testFoldingRange(
        \\//#region
        \\const foo = 0;
        \\//#region
        \\const bar = 1;
        \\//#endregion
        \\const baz = 2;
        \\//#endregion
    , &.{
        .{ .startLine = 2, .startCharacter = 0, .endLine = 4, .endCharacter = 12, .kind = .region },
        .{ .startLine = 0, .startCharacter = 0, .endLine = 6, .endCharacter = 12, .kind = .region },
    });
}

test "foldingRange - if" {
    try testFoldingRange(
        \\const foo = if (false) {
        \\
        \\};
    , &.{
        .{ .startLine = 0, .startCharacter = 24, .endLine = 2, .endCharacter = 0 },
    });
    try testFoldingRange(
        \\const foo = if (false) {
        \\
        \\} else {
        \\
        \\};
    , &.{
        .{ .startLine = 0, .startCharacter = 24, .endLine = 2, .endCharacter = 0 },
        .{ .startLine = 2, .startCharacter = 8, .endLine = 4, .endCharacter = 0 },
    });
}

test "foldingRange - for/while" {
    try testFoldingRange(
        \\const foo = for ("") |_| {
        \\
        \\};
    , &.{
        .{ .startLine = 0, .startCharacter = 26, .endLine = 2, .endCharacter = 0 },
    });
    try testFoldingRange(
        \\const foo = while (true) {
        \\
        \\};
    , &.{
        .{ .startLine = 0, .startCharacter = 26, .endLine = 2, .endCharacter = 0 },
    });
}

test "foldingRange - switch" {
    try testFoldingRange(
        \\const foo = switch (5) {
        \\  0 => {},
        \\  1 => {}
        \\};
    , &.{
        .{ .startLine = 0, .startCharacter = 24, .endLine = 3, .endCharacter = 0 },
    });
    try testFoldingRange(
        \\const foo = switch (5) {
        \\  0 => {},
        \\  1 => {},
        \\};
    , &.{
        .{ .startLine = 0, .startCharacter = 24, .endLine = 3, .endCharacter = 0 },
    });
}

test "foldingRange - function" {
    try testFoldingRange(
        \\fn main() u32 {
        \\    return 1 + 1;
        \\}
    , &.{
        .{ .startLine = 0, .startCharacter = 15, .endLine = 2, .endCharacter = 0 },
    });
    try testFoldingRange(
        \\fn main(
        \\  a: ?u32,
        \\) u32 {
        \\    return 1 + 1;
        \\}
    , &.{
        .{ .startLine = 0, .startCharacter = 8, .endLine = 2, .endCharacter = 0 },
        .{ .startLine = 2, .startCharacter = 7, .endLine = 4, .endCharacter = 0 },
    });
}

test "foldingRange - function with doc comment" {
    try testFoldingRange(
        \\/// this is
        \\/// a function
        \\fn foo(
        \\    /// this is a parameter
        \\    a: u32,
        \\    ///
        \\    /// this is another parameter
        \\    b: u32,
        \\) void {}
    , &.{
        .{ .startLine = 0, .startCharacter = 0, .endLine = 1, .endCharacter = 14, .kind = .comment },
        .{ .startLine = 5, .startCharacter = 4, .endLine = 6, .endCharacter = 33, .kind = .comment },
        .{ .startLine = 2, .startCharacter = 7, .endLine = 8, .endCharacter = 0 },
    });
}

test "foldingRange - container decl" {
    try testFoldingRange(
        \\const Foo = struct {
        \\  alpha: u32,
        \\  beta: []const u8,
        \\};
    , &.{
        .{ .startLine = 0, .startCharacter = 20, .endLine = 3, .endCharacter = 0 },
    });
    try testFoldingRange(
        \\const Foo = packed struct(u32) {
        \\  alpha: u16,
        \\  beta: u16,
        \\};
    , &.{
        // .{ .startLine = 0, .startCharacter = 32, .endLine = 3, .endCharacter = 0 }, // TODO
        .{ .startLine = 0, .startCharacter = 32, .endLine = 2, .endCharacter = 11 },
    });
    try testFoldingRange(
        \\const Foo = union {
        \\  alpha: u32,
        \\  beta: []const u8,
        \\};
    , &.{
        .{ .startLine = 0, .startCharacter = 19, .endLine = 3, .endCharacter = 0 },
    });
    try testFoldingRange(
        \\const Foo = union(enum) {
        \\  alpha: u32,
        \\  beta: []const u8,
        \\};
    , &.{
        .{ .startLine = 0, .startCharacter = 25, .endLine = 3, .endCharacter = 0 },
    });
}

test "foldingRange - call" {
    try testFoldingRange(
        \\extern fn foo(a: bool, b: ?usize) void;
        \\const result = foo(
        \\    false,
        \\    null,  
        \\);
    , &.{
        .{ .startLine = 1, .startCharacter = 19, .endLine = 4, .endCharacter = 0 },
    });
}

test "foldingRange - multi-line string literal" {
    try testFoldingRange(
        \\const foo =
        \\    \\hello
        \\    \\world
        \\;
    , &.{
        .{ .startLine = 1, .startCharacter = 4, .endLine = 3, .endCharacter = 0 },
    });
}

fn testFoldingRange(source: []const u8, expect: []const types.FoldingRange) !void {
    var ctx = try Context.init();
    defer ctx.deinit();

    const test_uri: []const u8 = switch (builtin.os.tag) {
        .windows => "file:///C:\\test.zig",
        else => "file:///test.zig",
    };

    try ctx.requestDidOpen(test_uri, source);

    const params = types.FoldingRangeParams{ .textDocument = .{ .uri = test_uri } };

    const response = try ctx.requestGetResponse(?[]types.FoldingRange, "textDocument/foldingRange", params);

    var actual = std.ArrayListUnmanaged(u8){};
    defer actual.deinit(allocator);

    var expected = std.ArrayListUnmanaged(u8){};
    defer expected.deinit(allocator);

    const options = std.json.StringifyOptions{ .emit_null_optional_fields = false, .whitespace = .{ .indent = .None } };
    try tres.stringify(response.result, options, actual.writer(allocator));
    try tres.stringify(expect, options, expected.writer(allocator));

    // TODO: Actually compare strings as JSON values.
    try std.testing.expectEqualStrings(expected.items, actual.items);
}
