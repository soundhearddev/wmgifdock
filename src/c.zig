pub const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/extensions/shape.h");
    @cInclude("Imlib2.h");
});
