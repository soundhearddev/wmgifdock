#ifndef WMSLIDESHOWCLASS_HPP_INCLUDED
#define WMSLIDESHOWCLASS_HPP_INCLUDED

#define APPNAME "wmgifdock"
#define VERSION "1.0"

#define CLASSNAME "wmgifdock"
#define INSTANCENAME "wmgifdock"

const char *const wClassName = CLASSNAME;
const char *const wInstanceName = INSTANCENAME;

#include <X11/Xlib.h>
#include <X11/extensions/shape.h>
#include <Imlib2.h>

class WMWindowDock
{
    Display *mDisplay;
    Visual *visual;
    Window mRoot;
    Window mAppWin;
    Window mIconWin;
    GC gc;
    Imlib_Image image;
    Imlib_Image buffer;
    Pixmap pix;
    std::string filename;
    std::string mInstanceName;
    XClassHint  classHint;
    XSizeHints  sizeHints;
    XWMHints    wmHints;
    Atom        deleteWindow;

    unsigned long   gcm;
    unsigned int	borderwidth;
    int dummy;
    int screen;
    int depth;
    int width;
    int height;
    float stime;
    int isize;
    int custom_size;

    char *Geometry;

    char *displayName;

public:
    XEvent event;


    WMWindowDock() {
        dummy = 0;
        screen = 0;
        depth = 0;
        width = 64;
        height = 64;
        stime = 1.0f;
        isize = 56;
        custom_size = 0;
        borderwidth = 1;
        displayName = NULL;
        Geometry  = NULL;//"";
    };
    virtual ~WMWindowDock() {};
    void parseCmLine(int argc, char **argv);
    void filesGetter();
    void openXup(int argc, char **argv);
    void DisplayImage();
    void setBuffer(Imlib_Image im);
    int load_err_image(std::string path);
    void usage(char **argv);
    //inline

    inline int getScreen(){ return screen; }
    inline Display *getDisplay() { return mDisplay; }
    inline Window getIconWin() { return mIconWin; }
    inline Window getAppWin() { return mAppWin; }
    inline Pixmap getPixMap() { return pix; }
    inline GC getGC() { return gc; }
    inline float getStime() { return stime; }
    inline int getWidth() { return width; }
    inline int getHeight() { return height; }
    inline int getIsize() { return isize; }
    inline Imlib_Image getImage() { return image; }
    inline WMWindowDock &getObject() { return *this; }
    inline Imlib_Image getBuffer() { return buffer; }
};

#endif // WMSLIDESHOW_HPP_INCLUDED