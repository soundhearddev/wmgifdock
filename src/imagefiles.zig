//! Portierung von imagefiles.cpp/imagefiles.hpp.
//!
//! Das urspruengliche Programm konnte ganze Verzeichnisse nach Bildern
//! durchsuchen (loadFiles, boost::filesystem::recursive_directory_iterator)
//! und zufaellig eins auswaehlen (getRany, get_random_file). wmgifdock
//! spielt aber nur eine einzelne Datei ab (-e <gif_file>), diese Funktionen
//! wurden im echten Programm gar nicht mehr benutzt (main.cpp ruft nur
//! parseCmLine -> filesGetter -> openXup -> DisplayImage auf, nie loadFiles
//! o.ae.). Deshalb bleibt hier nur das, was main.zig tatsaechlich braucht:
//!   - Existenz-/Typpruefung einer einzelnen Datei
//!   - Laden eines animierten Bildes samt aller Frames via zigimg
//!
//! TODO: falls doch Verzeichnis-Scan/Zufallsauswahl gebraucht wird (wie im
//! alten loadFiles/getRany), das hier mit std.fs.Dir.walk() + std.Random
//! nachbauen. Aktuell unnoetig, da main.zig nur -e <datei> unterstuetzt.

const std = @import("std");
const zigimg = @import("zigimg");

pub const supported_extensions = [_][]const u8{ "jpg", "jpeg", "png", "gif", "xpm", "bmp" };

/// Endung einer Datei (ohne Punkt), lowercased. Entspricht altem getFileExt().
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

/// Entspricht altem checkIfFile(). Nutzt statFile() statt cwd().access(), da
/// wir zusaetzlich zur Existenz auch den Dateityp brauchen (kein Verzeichnis).
pub fn checkIfFile(io: std.Io, path: []const u8) bool {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return stat.kind == .file;
}

/// Entspricht altem checkIfDirectory().
pub fn checkIfDirectory(io: std.Io, path: []const u8) bool {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return stat.kind == .directory;
}

pub const LoadError = anyerror;

/// Ein einzelner Frame, bereits garantiert im rgba32-Format (nicht
/// premultiplied -- die Premultiplikation passiert erst in render.zig bei
/// der Konvertierung nach ARGB fuer Imlib2, analog zu convert_rgba_to_argb()
/// im Original, das ebenfalls von unpremultipliedem RGBA ausgeht, wie es
/// MagickExportImagePixels(..., "RGBA", ...) liefert).
pub const Frame = struct {
    pixels: []zigimg.color.Rgba32, // eigentuemlich, muss gefreed werden
    width: usize,
    height: usize,
    /// Anzeigedauer in Millisekunden. GIF-Frames mit delay=0 werden wie im
    /// alten Code (MagickGetImageDelay -> delay==0 -> 4 Hundertstelsekunden
    /// = 40ms) auf einen sinnvollen Minimalwert angehoben.
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

/// Laedt eine Bild-/GIF-Datei und liefert alle Frames als rgba32 zurueck.
/// Entspricht dem MagickWand-Teil von WMWindowDock::DisplayImage() in
/// wmgifdock.cpp (ReadImage + CoalesceImages + Iteration ueber alle Frames +
/// ExportImagePixels als RGBA).
///
/// Wichtig, analog zu MagickCoalesceImages() im Original: bei animierten
/// GIFs beschreibt jeder rohe Frame oft nur eine Teilregion des Bildes
/// relativ zum vorherigen Frame (disposal methods). zigimg's
/// image.animation.frames sind bereits vollstaendig zusammengesetzte
/// (coalesced) Frames in Bildgroesse -- das entspricht exakt dem, was
/// MagickCoalesceImages() im Original leistet, es muss hier also nichts
/// zusaetzlich zusammengesetzt werden.
pub fn loadAllFrames(allocator: std.mem.Allocator, io_instance: std.Io, path: []const u8) LoadError!LoadedImage {
    var read_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    var image = try zigimg.Image.fromFilePath(allocator, io_instance, path, read_buffer[0..]);
    defer image.deinit(allocator);

    var frames = std.ArrayList(Frame).empty;
    errdefer {
        for (frames.items) |f| allocator.free(f.pixels);
        frames.deinit(allocator);
    }

    if (image.isAnimation()) {
        try frames.ensureTotalCapacityPrecise(allocator, image.animation.frames.items.len);
        for (image.animation.frames.items) |*frame| {
            const rgba = try framePixelsToRgba32(allocator, &frame.pixels);
            // GIF delay ist in Sekunden (f32) bei zigimg; altes Verhalten:
            // delay==0 -> Minimalwert statt 0ms (sonst busy loop / Flackern).
            var delay_ms: u32 = @intFromFloat(@round(frame.duration * 1000.0));
            if (delay_ms == 0) delay_ms = 40; // entspricht altem "delay = 4" (in 1/100s = 40ms)
            frames.appendAssumeCapacity(.{
                .pixels = rgba,
                .width = image.width,
                .height = image.height,
                .delay_ms = delay_ms,
            });
        }
    } else {
        // Standbild: ein einziger "Frame" ohne Animation.
        const rgba = try framePixelsToRgba32(allocator, &image.pixels);
        try frames.append(allocator, .{
            .pixels = rgba,
            .width = image.width,
            .height = image.height,
            .delay_ms = 0,
        });
    }

    if (frames.items.len == 0) return LoadError.NoFrames;

    return .{
        .frames = try frames.toOwnedSlice(allocator),
        .width = image.width,
        .height = image.height,
    };
}

/// Konvertiert ein beliebiges PixelStorage (indexed1/2/4/8, rgba32, ...) in
/// eine frisch allozierte rgba32-Kopie. Nutzt PixelFormatConverter direkt
/// statt Image.convert(), weil Image.convert() nur image.pixels (= erster
/// Frame) anfasst, nicht die einzelnen animation.frames Eintraege.
fn framePixelsToRgba32(allocator: std.mem.Allocator, pixels: *zigimg.color.PixelStorage) LoadError![]zigimg.color.Rgba32 {
    if (std.meta.activeTag(pixels.*) == .rgba32) {
        // Bereits im richtigen Format: kopieren, damit deinit() der
        // Original-Frames uns nichts unter dem Allocator wegzieht.
        const src = pixels.rgba32;
        const copy = try allocator.alloc(zigimg.color.Rgba32, src.len);
        @memcpy(copy, src);
        return copy;
    }

    const converted = zigimg.PixelFormatConverter.convert(allocator, pixels, .rgba32) catch {
        return LoadError.UnsupportedPixelFormat;
    };
    // converted ist ein PixelStorage, wir wollen nur den rgba32-Slice
    // rausziehen und den Rest der Struktur nicht extra freigeben, da
    // PixelStorage fuer rgba32 keine zusaetzliche Allokation (z.B. Palette)
    // haelt.
    return converted.rgba32;
}
