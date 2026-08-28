const std = @import("std");
const wmgifdock = @import("wmgifdock.zig");
const render = @import("render.zig");

/// Installiert SIGTERM/SIGINT-Handler, die render.should_exit setzen, damit
/// die Animationsschleife kontrolliert beendet wird und alle defer-Bloecke
/// (XContext.close, Frame-Freigabe etc.) noch laufen.
fn installSignalHandlers() void {
    const sa: std.posix.Sigaction = .{
        .handler = .{ .handler = handleExitSignal },
        .mask = [_]c_ulong{0} ** 16,
        .flags = 0,
    };

    std.posix.sigaction(std.posix.SIG.TERM, &sa, null);
    std.posix.sigaction(std.posix.SIG.INT, &sa, null);
}

fn handleExitSignal(_: std.posix.SIG) callconv(.c) void {
    render.should_exit.store(true, .release);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    const prog_name = if (args.len > 0) args[0] else "wmgifdock";

    const opts = wmgifdock.parseCmLine(args) catch {
        wmgifdock.usage(prog_name);
        return;
    };

    if (!wmgifdock.filesGetter(io, opts)) {
        std.debug.print(
            "Error: file not found or not a regular file: {s}\n",
            .{opts.filename},
        );
        return;
    }

    installSignalHandlers();

    var xctx = wmgifdock.XContext.open(opts.size(), args) catch |err| {
        std.debug.print(
            "Error: could not open X display ({s})\n",
            .{@errorName(err)},
        );
        return;
    };
    defer xctx.close();

    render.displayImage(allocator, io, &xctx, opts) catch |err| {
        std.debug.print(
            "Error: could not display image ({s})\n",
            .{@errorName(err)},
        );
        return;
    };
}
