//! Portierung von wmgifdock.hpp/wmgifdock.cpp.

const std = @import("std");
const c = @import("c.zig").c;
const imagefiles = @import("imagefiles.zig");

pub const app_name = "wmgifdock";
pub const version = "1.0";
pub const class_name = "wmgifdock";
pub const instance_name = "wmgifdock";

pub const default_size: c_int = 64;
pub const min_size: c_int = 16;
pub const max_size: c_int = 256;
pub const default_speed: f32 = 1.0;

pub const Options = struct {
    filename: []const u8 = "",
    /// Geschwindigkeitsfaktor: 0.5 = 2x schneller, 1 = normal, 2 = 2x langsamer.
    speed: f32 = default_speed,
    /// 0 bedeutet "nicht gesetzt", dann wird default_size verwendet.
    custom_size: c_int = 0,

    pub fn size(self: Options) c_int {
        return if (self.custom_size > 0) self.custom_size else default_size;
    }
};

pub const ParseError = error{
    ShowUsage, // "-h" oder Fehler in der Kommandozeile: usage() ausgeben und beenden
};

/// Portierung von WMWindowDock::parseCmLine(). QoL-Verbesserungen ggue. dem
/// Original:
///   - "-t" ohne Angabe: Default 1.0 (war vorher auch schon so, jetzt mit
///     Meldung bei ungueltigem statt nur bei <= 0 stillem Fallback)
///   - "-e" ist jetzt wirklich Pflicht (wurde vorher erst spaeter beim
///     Datei-Zugriff unklar sichtbar)
///   - Datei-Existenzcheck ist strikter (checkIfFile statt nur
///     "kein Verzeichnis")
pub fn parseCmLine(args: []const []const u8) ParseError!Options {
    var opts = Options{};

    if (args.len < 2) return ParseError.ShowUsage;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-t")) {
            if (i + 1 >= args.len) return ParseError.ShowUsage;
            i += 1;
            const speed = std.fmt.parseFloat(f32, args[i]) catch 0;
            if (speed <= 0) {
                std.debug.print("Speed must be > 0, using default 1.0.\n", .{});
                opts.speed = default_speed;
            } else {
                opts.speed = speed;
            }
        } else if (std.mem.eql(u8, arg, "-e")) {
            if (i + 1 >= args.len) return ParseError.ShowUsage;
            i += 1;
            opts.filename = args[i];
        } else if (std.mem.eql(u8, arg, "-s")) {
            if (i + 1 >= args.len) return ParseError.ShowUsage;
            i += 1;
            const sz = std.fmt.parseInt(c_int, args[i], 10) catch 0;
            if (sz >= min_size and sz <= max_size) {
                opts.custom_size = sz;
            } else {
                std.debug.print("Size must be between {d} and {d}, using default {d}.\n", .{ min_size, max_size, default_size });
            }
        } else if (std.mem.eql(u8, arg, "-h")) {
            return ParseError.ShowUsage;
        } else {
            return ParseError.ShowUsage;
        }
    }

    if (opts.filename.len == 0) {
        std.debug.print("Error: no GIF file given (-e <gif_file>)\n", .{});
        return ParseError.ShowUsage;
    }

    return opts;
}

pub fn usage(prog_name: []const u8) void {
    std.debug.print(
        \\
        \\{s} {s}
        \\
        \\GIF Animation Player for Dock
        \\
        \\{s} -e <gif_file>     : Path to GIF file to play
        \\{s} -t <speed>        : Speed (0.5=2x faster, 1=normal, 2=2x slower)
        \\{s} -s <size>         : Window size in pixels (16-256, default 64)
        \\{s} -h                : Display this help
        \\
        \\
    , .{ app_name, version, prog_name, prog_name, prog_name, prog_name });
}

/// Portierung von WMWindowDock::filesGetter(). Prueft, dass die angegebene
/// Datei existiert und eine regulaere Datei ist (kein Verzeichnis).
pub fn filesGetter(io: std.Io, opts: Options) bool {
    return imagefiles.checkIfFile(io, opts.filename);
}

/// Haelt alle X11-Ressourcen. Entspricht den privaten Membern von
/// WMWindowDock in wmgifdock.hpp.
pub const XContext = struct {
    display: *c.Display,
    root: c.Window,
    app_win: c.Window,
    icon_win: c.Window,
    gc: c.GC,
    pix: c.Pixmap,
    visual: *c.Visual,
    screen: c_int,
    depth: c_int,
    delete_window: c.Atom,

    /// Portierung von WMWindowDock::openXup(). Baut Withdrawn-State Dockapp
    /// Fenster + Icon-Fenster auf, exakt wie im Original.
    ///
    /// `argv` wird fuer XSetCommand() durchgereicht (Session-Management: der
    /// Window-Manager kann damit das Programm mit denselben Argumenten neu
    /// starten). Das entspricht dem Original, wo XSetCommand(display, app_win,
    /// argv, argc) direkt in openXup() aufgerufen wird. Der Typ [][:0]u8
    /// entspricht exakt dem Rueckgabetyp von std.process.argsAlloc().
    pub fn open(size: c_int, argv: []const [:0]const u8) !XContext {
        const display = c.XOpenDisplay(null) orelse return error.CannotOpenDisplay;
        errdefer _ = c.XCloseDisplay(display);

        const root = c.RootWindow(display, c.DefaultScreen(display));

        const app_win = c.XCreateSimpleWindow(display, root, 1, 1, @intCast(size), @intCast(size), 1, 1, 0);
        const icon_win = c.XCreateSimpleWindow(display, app_win, 0, 0, @intCast(size), @intCast(size), 0, 0, 0);
        const gc = c.XCreateGC(display, icon_win, 0, null);

        const screen = c.XDefaultScreen(display);
        const depth = c.DefaultDepth(display, screen);
        const pix = c.XCreatePixmap(display, root, @intCast(size), @intCast(size), @intCast(depth));

        // Original: classHint.res_name = wInstanceName; classHint.res_class = wClassName;
        // (in wmgifdock.hpp sind beide Strings identisch = "wmgifdock", die
        // Zuordnung ist trotzdem semantisch exakt so uebernommen, falls die
        // Konstanten irgendwann divergieren sollten)
        var class_hint: c.XClassHint = .{
            .res_name = @constCast(instance_name.ptr),
            .res_class = @constCast(class_name.ptr),
        };
        _ = c.XSetClassHint(display, app_win, &class_hint);

        _ = c.XSelectInput(display, app_win, c.ButtonPressMask | c.ExposureMask | c.ButtonReleaseMask |
            c.PointerMotionMask | c.StructureNotifyMask);
        _ = c.XSelectInput(display, icon_win, c.ButtonPressMask | c.ExposureMask | c.ButtonReleaseMask |
            c.PointerMotionMask | c.StructureNotifyMask);

        var delete_window = c.XInternAtom(display, "WM_DELETE_WINDOW", c.False);
        _ = c.XSetWMProtocols(display, app_win, &delete_window, 1);
        _ = c.XSetWMProtocols(display, icon_win, &delete_window, 1);

        _ = c.XStoreName(display, app_win, app_name);
        _ = c.XSetIconName(display, app_win, app_name);

        var size_hints: c.XSizeHints = std.mem.zeroes(c.XSizeHints);
        size_hints.flags = c.USSize | c.USPosition;
        size_hints.x = 0;
        size_hints.y = 0;
        c.XSetWMNormalHints(display, app_win, &size_hints);

        var wm_hints: c.XWMHints = std.mem.zeroes(c.XWMHints);
        wm_hints.initial_state = c.WithdrawnState;
        wm_hints.icon_window = icon_win;
        wm_hints.icon_x = 0;
        wm_hints.icon_y = 0;
        wm_hints.window_group = app_win;
        wm_hints.flags = c.StateHint | c.IconWindowHint | c.WindowGroupHint | c.IconPositionHint;
        _ = c.XSetWMHints(display, app_win, &wm_hints);

        // Entspricht XSetCommand(display, app_win, argv, argc) im Original:
        // Session-Manager/Window-Manager koennen damit das Programm mit den
        // gleichen Kommandozeilenargumenten neu starten. XSetCommand erwartet
        // char** (Array von rohen Zeigern), std.process.argsAlloc() liefert
        // aber [][:0]u8 (Slices mit Laenge). Deshalb hier ein kurzlebiges
        // Array reiner Pointer aufbauen -- argv.len ist typischerweise
        // einstellig bis niedrig zweistellig, ein Stack-Array mit
        // Kapazitaetsgrenze ist also unproblematisch.
        var argv_ptrs_buf: [64][*c]u8 = undefined;
        const argc_for_x: usize = @min(argv.len, argv_ptrs_buf.len);
        for (argv[0..argc_for_x], 0..) |arg, idx| argv_ptrs_buf[idx] = @ptrCast(@constCast(arg.ptr));
        _ = c.XSetCommand(display, app_win, @ptrCast(&argv_ptrs_buf), @intCast(argc_for_x));

        _ = c.XMapWindow(display, app_win);
        _ = c.XMapWindow(display, icon_win);
        _ = c.XClearWindow(display, app_win);
        _ = c.XClearWindow(display, icon_win);
        _ = c.XFlush(display);

        const visual = c.DefaultVisual(display, c.DefaultScreen(display));

        return .{
            .display = display,
            .root = root,
            .app_win = app_win,
            .icon_win = icon_win,
            .gc = gc,
            .pix = pix,
            .visual = visual,
            .screen = screen,
            .depth = depth,
            .delete_window = delete_window,
        };
    }

    pub fn close(self: *XContext) void {
        _ = c.XFreeGC(self.display, self.gc);
        _ = c.XFreePixmap(self.display, self.pix);
        _ = c.XDestroyWindow(self.display, self.icon_win);
        _ = c.XDestroyWindow(self.display, self.app_win);
        _ = c.XCloseDisplay(self.display);
    }
};
