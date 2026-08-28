//! Portierung von WMWindowDock::DisplayImage() und convert_rgba_to_argb()
//! aus wmgifdock.cpp. Der MagickWand-Teil (Laden + Frame-Extraktion,
//! inklusive MagickCoalesceImages) ist komplett durch imagefiles.zig/zigimg
//! ersetzt; hier bleibt nur noch das Imlib2-Scaling und X11-Rendering, plus
//! der Animations-Loop.

const std = @import("std");
const c = @import("c.zig").c;
const zigimg = @import("zigimg");
const imagefiles = @import("imagefiles.zig");
const wmgifdock = @import("wmgifdock.zig");

/// Wird von main.zig per Signal-Handler (SIGTERM/SIGINT) gesetzt, damit die
/// Animationsschleife kontrolliert beendet werden kann statt nur per SIGKILL.
/// Das Original hatte gar kein Exit-Handling (reine while(true)-Endlosschleife,
/// Beenden nur durch harten Prozessabbruch von aussen); dieses Flag ist eine
/// reine Zusatzverbesserung und aendert am Kernverhalten (endlose Animation
/// bis zum Beenden) nichts.
pub var should_exit: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);

/// Entspricht convert_rgba_to_argb() im Original: RGBA -> premultiplied ARGB
/// wie Imlib2/X11 es fuer imlib_image_get_data()/put_back_data() erwartet.
fn convertRgbaToArgb(src: []const zigimg.color.Rgba32, dst: []u32) void {
    std.debug.assert(src.len == dst.len);
    for (src, 0..) |px, i| {
        const a: u32 = px.a;
        const r: u32 = (@as(u32, px.r) * a) / 255;
        const g: u32 = (@as(u32, px.g) * a) / 255;
        const b: u32 = (@as(u32, px.b) * a) / 255;
        dst[i] = (a << 24) | (r << 16) | (g << 8) | b;
    }
}

/// Portierung von WMWindowDock::DisplayImage(). Laedt das Bild einmal via
/// imagefiles.loadAllFrames(), initialisiert Imlib2 fuer das gegebene
/// X-Display und spielt die Frames dann in einer Schleife ab, bis
/// should_exit gesetzt wird (z.B. durch SIGTERM/SIGINT, siehe main.zig).
pub fn displayImage(allocator: std.mem.Allocator, io_instance: std.Io, xctx: *wmgifdock.XContext, opts: wmgifdock.Options) !void {
    var loaded = try imagefiles.loadAllFrames(allocator, io_instance, opts.filename);
    defer loaded.deinit(allocator);

    if (loaded.frames.len == 0) return error.NoFrames;

    const size = opts.size();

    c.imlib_context_set_display(xctx.display);
    c.imlib_context_set_visual(xctx.visual);
    c.imlib_context_set_colormap(c.DefaultColormap(xctx.display, c.DefaultScreen(xctx.display)));
    c.imlib_context_set_dither(1);
    c.imlib_context_set_blend(0);
    c.imlib_context_set_anti_alias(0);

    const scaled = c.imlib_create_image(@intCast(size), @intCast(size));
    if (scaled == null) return error.ImlibCreateImageFailed;
    defer {
        c.imlib_context_set_image(scaled);
        c.imlib_free_image();
    }

    // Zwischenpuffer fuer die ARGB-Konvertierung; einmal auf die groesste
    // Framegroesse allokieren und wiederverwenden statt pro Frame neu.
    var max_pixels: usize = 0;
    for (loaded.frames) |f| max_pixels = @max(max_pixels, f.width * f.height);
    const argb_scratch = try allocator.alloc(u32, max_pixels);
    defer allocator.free(argb_scratch);

    while (!should_exit.load(.acquire)) {
        for (loaded.frames) |frame| {
            if (should_exit.load(.acquire)) return;

            const pixel_count = frame.width * frame.height;
            const img = c.imlib_create_image(@intCast(frame.width), @intCast(frame.height));
            if (img == null) continue;

            c.imlib_context_set_image(img);
            const imlib_pixels_ptr = c.imlib_image_get_data();
            if (imlib_pixels_ptr == null) {
                c.imlib_free_image();
                continue;
            }
            const imlib_pixels: [*]u32 = @ptrCast(@alignCast(imlib_pixels_ptr));

            convertRgbaToArgb(frame.pixels, argb_scratch[0..pixel_count]);
            @memcpy(imlib_pixels[0..pixel_count], argb_scratch[0..pixel_count]);
            c.imlib_image_put_back_data(imlib_pixels);

            c.imlib_context_set_image(scaled);
            c.imlib_blend_image_onto_image(img, 1, 0, 0, @intCast(frame.width), @intCast(frame.height), 0, 0, @intCast(size), @intCast(size));

            c.imlib_context_set_drawable(xctx.pix);
            c.imlib_render_image_on_drawable_at_size(0, 0, @intCast(size), @intCast(size));

            _ = c.XSetWindowBackgroundPixmap(xctx.display, xctx.icon_win, xctx.pix);
            _ = c.XClearWindow(xctx.display, xctx.icon_win);
            _ = c.XFlush(xctx.display);

            c.imlib_context_set_image(img);
            c.imlib_free_image();

            // Original: delay_ns = delay(1/100s) * 10 * 1e6 * stime, d.h.
            // delay_ms = delay(1/100s) * 10 * stime. Hier ist frame.delay_ms
            // bereits in Millisekunden (siehe imagefiles.zig), daher genuegt
            // die Multiplikation mit dem Speed-Faktor.
            const delay_ms: u64 = @intFromFloat(@round(@as(f64, @floatFromInt(frame.delay_ms)) * opts.speed));
            try sleepInterruptible(io_instance, delay_ms);
        }
    }
}

/// Schlaeft in kleinen Schritten statt am Stueck, damit should_exit zeitnah
/// (statt erst nach dem vollen Frame-Delay) erkannt wird.
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
