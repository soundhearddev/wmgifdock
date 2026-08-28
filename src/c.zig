//! Rohe C-Bindings fuer Xlib und Imlib2 via @cImport.
//! Alles was von hier importiert wird ist 1:1 die C-API, keine Zig-Wrapper.
//!
//! Hinweis: X11-Header definieren "Bool" via #define True 1 / False 0.
//! zig translate-c macht daraus normale Integer-Konstanten (c.True / c.False,
//! bzw. wo als Funktionsparameter verwendet c_int 0/1). Kein Handlungsbedarf,
//! nur als Hinweis fuer Aufrufer, die statt Literalen 0/1 lieber c.False/
//! c.True verwenden wollen.

pub const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/extensions/shape.h");
    @cInclude("Imlib2.h");
});
