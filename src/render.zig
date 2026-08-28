//! Portierung von WMWindowDock::DisplayImage() und convert_rgba_to_argb() aus wmgifdock.cpp.

const std = @import("std");
const c = @import("c.zig").c;
const imagefiles = @import("imagefiles.zig");
const wmgifdock = @import("wmgifdock.zig");

pub var should_exit: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);

pub fn displayImage(allocator: std.mem.Allocator, io_instance: std.Io, xctx: *wmgifdock.XContext, opts: wmgifdock.Options) !void {
    const size = opts.size();

    // Frames bereits in Zielgröße (size x size) und fertigem ARGB laden
    var loaded = try imagefiles.loadAllFrames(allocator, io_instance, opts.filename, size);
    defer loaded.deinit(allocator);

    if (loaded.frames.len == 0) return error.NoFrames;

    c.imlib_context_set_display(xctx.display);
    c.imlib_context_set_visual(xctx.visual);
    c.imlib_context_set_colormap(c.DefaultColormap(xctx.display, c.DefaultScreen(xctx.display)));
    c.imlib_context_set_dither(1);
    c.imlib_context_set_blend(0);
    c.imlib_context_set_anti_alias(0);

    // Ein einziges Imlib2-Image für alle Frames erstellen und wiederverwenden
    const img = c.imlib_create_image(@intCast(size), @intCast(size));
    if (img == null) return error.ImlibCreateImageFailed;
    defer {
        c.imlib_context_set_image(img);
        c.imlib_free_image();
    }

    const pixel_count = @as(usize, size) * size;

    while (!should_exit.load(.acquire)) {
        for (loaded.frames) |frame| {
            if (should_exit.load(.acquire)) return;

            c.imlib_context_set_image(img);
            const imlib_pixels_ptr = c.imlib_image_get_data();
            if (imlib_pixels_ptr == null) continue;

            const imlib_pixels: [*]u32 = @ptrCast(@alignCast(imlib_pixels_ptr));

            // Direktes Verpflanzen der vorberechneten 64x64 ARGB-Pixel
            @memcpy(imlib_pixels[0..pixel_count], frame.pixels[0..pixel_count]);
            c.imlib_image_put_back_data(imlib_pixels);

            c.imlib_context_set_drawable(xctx.pix);
            c.imlib_render_image_on_drawable_at_size(0, 0, @intCast(size), @intCast(size));
            _ = c.XSetWindowBackgroundPixmap(xctx.display, xctx.icon_win, xctx.pix);
            _ = c.XClearWindow(xctx.display, xctx.icon_win);
            _ = c.XFlush(xctx.display);

            const delay_ms: u64 = @intFromFloat(@round(@as(f64, @floatFromInt(frame.delay_ms)) * opts.speed));
            try sleepInterruptible(io_instance, delay_ms);
        }
    }
}

fn sleepInterruptible(io_instance: std.Io, total_ms: u64) !void {
    const step_ms: u64 = 50;
    var remaining = total_ms;
    while (remaining > 0) {
        if (should_exit.load(.acquire)) return;

        const chunk = @min(remaining, step_ms);
        try io_instance.sleep(
            .fromNanoseconds(@as(u64, chunk) * 1_000_000),
            .awake,
        );
        remaining -= chunk;
    }
}
