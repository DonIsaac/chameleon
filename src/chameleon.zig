const std = @import("std");
pub const ComptimeChameleon = @import("api/Comptime.zig");
pub const RuntimeChameleon = @import("api/Runtime.zig");
pub const HexColors = @import("colors.zig");

pub fn initComptime() ComptimeChameleon {
    return .{};
}

const Config = struct {
    allocator: std.mem.Allocator,
    detect_no_color: bool = true,
    /// Process environment used to detect `NO_COLOR`. Zig 0.17 no longer
    /// exposes the environment globally, so pass `init.minimal.environ` from
    /// `main`. When `null`, `NO_COLOR` is not detected.
    environ: ?std.process.Environ = null,
};

pub fn initRuntime(config: Config) RuntimeChameleon {
    return .{
        .allocator = config.allocator,
        .no_color = config.detect_no_color and
            if (config.environ) |env| env.containsConstant("NO_COLOR") else false,
    };
}

test {
    std.testing.refAllDecls(@This());
}

fn expectFileContents(dir: std.Io.Dir, sub_path: []const u8, expected: []const u8) !void {
    const contents = try dir.readFileAlloc(std.testing.io, sub_path, std.testing.allocator, .limited(1024));
    defer std.testing.allocator.free(contents);
    try std.testing.expectEqualStrings(expected, contents);
}

test "Runtime file print helpers" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var c = initRuntime(.{ .allocator = std.testing.allocator });
    defer c.deinit();

    {
        const file = try tmp.dir.createFile(io, "unbuffered", .{});
        defer file.close(io);
        try c.red().printFile(io, file, "{s}", .{"x"});
    }
    try expectFileContents(tmp.dir, "unbuffered", "\x1b[31mx\x1b[39m");

    {
        const file = try tmp.dir.createFile(io, "buffered", .{});
        defer file.close(io);
        try c.red().printFileBuffered(io, file, "{s}", .{"x"});
    }
    try expectFileContents(tmp.dir, "buffered", "\x1b[31mx\x1b[39m");

    // No styles and an empty format writes nothing; this exercises the
    // stdout/stderr wrappers without polluting test output.
    try c.printOut(io, "", .{});
    try c.printErr(io, "", .{});
    try c.printOutBuffered(io, "", .{});
    try c.printErrBuffered(io, "", .{});
}

test "Comptime file print helpers" {
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    comptime var c = initComptime();

    {
        const file = try tmp.dir.createFile(io, "unbuffered", .{});
        defer file.close(io);
        try c.red().printFile(io, file, "{s}", .{"x"});
    }
    try expectFileContents(tmp.dir, "unbuffered", "\x1b[31mx\x1b[39m");

    {
        const file = try tmp.dir.createFile(io, "buffered", .{});
        defer file.close(io);
        try c.red().printFileBuffered(io, file, "{s}", .{"x"});
    }
    try expectFileContents(tmp.dir, "buffered", "\x1b[31mx\x1b[39m");

    try c.printOut(io, "", .{});
    try c.printErr(io, "", .{});
    try c.printOutBuffered(io, "", .{});
    try c.printErrBuffered(io, "", .{});
}

test "initRuntime detects NO_COLOR from environ" {
    if (std.process.Environ.Block != std.process.Environ.PosixBlock) return error.SkipZigTest;
    const with: std.process.Environ = .{ .block = .{ .slice = &.{ "FOO=bar", "NO_COLOR=1" } } };
    const without: std.process.Environ = .{ .block = .{ .slice = &.{"FOO=bar"} } };
    const a = std.testing.allocator;

    try std.testing.expect(initRuntime(.{ .allocator = a, .environ = with }).no_color);
    try std.testing.expect(!initRuntime(.{ .allocator = a, .environ = without }).no_color);
    try std.testing.expect(!initRuntime(.{ .allocator = a, .environ = with, .detect_no_color = false }).no_color);
    try std.testing.expect(!initRuntime(.{ .allocator = a }).no_color);
}
