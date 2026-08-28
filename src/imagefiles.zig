const std = @import("std");
const zigimg = @import("zigimg");
const c = @import("c.zig").c;

pub const supported_extensions = [_][]const u8{ "jpg", "jpeg", "png", "gif", "xpm", "bmp" };

pub fn fileExt(path: []const u8, buf: []u8) []const u8 {
    const dot = std.mem.lastIndexOfScalar(u8, path, '.') orelse return "";
    const raw = path[dot + 1 ..];
    const n = @min(raw.len, buf.len);
    for (raw[0..n], 0..) |ch, i| buf[i] = std.ascii.toLower(ch);
    return buf[0..n];
}

pub fn isSupportedExt(ext: []const u8) bool {
    for (supported_extensions) |candidate| {
        if (std.ascii.eqlIgnoreCase(ext, candidate)) return true;
    }
    return false;
}

pub fn checkIfFile(io: std.Io, path: []const u8) bool {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return stat.kind == .file;
}

pub fn checkIfDirectory(io: std.Io, path: []const u8) bool {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return stat.kind == .directory;
}

pub const LoadError = anyerror;

pub const Frame = struct {
    pixels: []u32,
    delay_ms: u32,
};

pub const LoadedImage = struct {
    frames: []Frame,
    width: usize,
    height: usize,

    pub fn deinit(self: *LoadedImage, allocator: std.mem.Allocator) void {
        for (self.frames) |f| allocator.free(f.pixels);
        allocator.free(self.frames);
        self.* = undefined;
    }
};

inline fn div255(v: u32) u32 {
    return (v * 257 + 257) >> 16;
}

fn convertRgbaToArgb(src: []const zigimg.color.Rgba32, dst: []u32) void {
    std.debug.assert(src.len == dst.len);
    for (src, 0..) |px, i| {
        const a: u32 = px.a;
        if (a == 255) {
            dst[i] = (0xFF << 24) | (@as(u32, px.r) << 16) | (@as(u32, px.g) << 8) | px.b;
        } else if (a == 0) {
            dst[i] = 0;
        } else {
            const r = div255(@as(u32, px.r) * a);
            const g = div255(@as(u32, px.g) * a);
            const b = div255(@as(u32, px.b) * a);
            dst[i] = (a << 24) | (r << 16) | (g << 8) | b;
        }
    }
}

pub fn loadAllFrames(allocator: std.mem.Allocator, io_instance: std.Io, path: []const u8, target_size: u32) LoadError!LoadedImage {
    var read_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    var image = try zigimg.Image.fromFilePath(allocator, io_instance, path, read_buffer[0..]);
    defer image.deinit(allocator);

    var raw_frames = std.ArrayList(struct { rgba: []zigimg.color.Rgba32, delay_ms: u32 }).empty;
    defer {
        for (raw_frames.items) |f| allocator.free(f.rgba);
        raw_frames.deinit(allocator);
    }

    if (image.isAnimation()) {
        try raw_frames.ensureTotalCapacityPrecise(allocator, image.animation.frames.items.len);
        for (image.animation.frames.items) |*frame| {
            const rgba = try framePixelsToRgba32(allocator, &frame.pixels);
            var delay_ms: u32 = @intFromFloat(@round(frame.duration * 1000.0));
            if (delay_ms == 0) delay_ms = 40;
            raw_frames.appendAssumeCapacity(.{ .rgba = rgba, .delay_ms = delay_ms });
        }
    } else {
        const rgba = try framePixelsToRgba32(allocator, &image.pixels);
        try raw_frames.append(allocator, .{ .rgba = rgba, .delay_ms = 0 });
    }

    if (raw_frames.items.len == 0) return LoadError.NoFrames;

    var scaled_frames = std.ArrayList(Frame).empty;
    errdefer {
        for (scaled_frames.items) |f| allocator.free(f.pixels);
        scaled_frames.deinit(allocator);
    }
    try scaled_frames.ensureTotalCapacityPrecise(allocator, raw_frames.items.len);

    const pixel_count_target = @as(usize, target_size) * target_size;
    const src_width = image.width;
    const src_height = image.height;

    const src_argb = try allocator.alloc(u32, src_width * src_height);
    defer allocator.free(src_argb);

    for (raw_frames.items) |rf| {
        convertRgbaToArgb(rf.rgba, src_argb);

        const img_src = c.imlib_create_image_using_copied_data(@intCast(src_width), @intCast(src_height), src_argb.ptr);
        if (img_src == null) return LoadError.OutOfMemory;
        defer {
            c.imlib_context_set_image(img_src);
            c.imlib_free_image();
        }

        c.imlib_context_set_image(img_src);
        const img_scaled = c.imlib_create_cropped_scaled_image(0, 0, @intCast(src_width), @intCast(src_height), @intCast(target_size), @intCast(target_size));
        if (img_scaled == null) return LoadError.OutOfMemory;
        defer {
            c.imlib_context_set_image(img_scaled);
            c.imlib_free_image();
        }

        c.imlib_context_set_image(img_scaled);
        const scaled_pixels_ptr = c.imlib_image_get_data_for_reading_only();
        if (scaled_pixels_ptr == null) return LoadError.OutOfMemory;

        const frame_buf = try allocator.alloc(u32, pixel_count_target);
        const scaled_slice: [*]const u32 = @ptrCast(@alignCast(scaled_pixels_ptr));
        @memcpy(frame_buf, scaled_slice[0..pixel_count_target]);

        scaled_frames.appendAssumeCapacity(.{
            .pixels = frame_buf,
            .delay_ms = rf.delay_ms,
        });
    }

    return .{
        .frames = try scaled_frames.toOwnedSlice(allocator),
        .width = target_size,
        .height = target_size,
    };
}

fn framePixelsToRgba32(allocator: std.mem.Allocator, pixels: *zigimg.color.PixelStorage) LoadError![]zigimg.color.Rgba32 {
    if (std.meta.activeTag(pixels.*) == .rgba32) {
        const src = pixels.rgba32;
        const copy = try allocator.alloc(zigimg.color.Rgba32, src.len);
        @memcpy(copy, src);
        return copy;
    }

    const converted = zigimg.PixelFormatConverter.convert(allocator, pixels, .rgba32) catch {
        return LoadError.UnsupportedPixelFormat;
    };
    return converted.rgba32;
}
