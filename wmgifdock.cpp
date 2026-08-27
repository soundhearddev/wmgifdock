#include <iostream>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <string>
#include <cctype>
#include <unistd.h>
#include <time.h>
#include <vector>
#include <X11/extensions/shape.h>
#include <Imlib2.h>
#include <MagickWand/MagickWand.h>
#include "wmgifdock.hpp"
#include "imagefiles.hpp"

// Frame-Cache struct
struct CachedFrame {
    unsigned char *pixels;
    size_t width;
    size_t height;
    size_t delay;
};

void WMWindowDock::parseCmLine(int argc, char **argv)
{

    if (argc > 1)
    {
        for (int i = 1; i <  argc; i++)
        {
            if (!strcmp(argv[i], "-t") )
            {
                if ( argv[i+1] == NULL)
                {
                    usage(argv);
                    exit(0);
                }
                // Parse speed as float (0.5=2x faster, 1=normal, 2=2x slower)
                float speed = atof(argv[++i]);
                if (speed <= 0)
                    speed = 1.0f;
                stime = speed;
            }
            else if (!strcmp(argv[i], "-e"))
            {
                if ( argv[i+1] == NULL)
                {
                    usage(argv);
                    exit(0);
                }
                filename = argv[++i];
            }
            else if (!strcmp(argv[i], "-s"))
            {
                if ( argv[i+1] == NULL)
                {
                    usage(argv);
                    exit(0);
                }
                int size = atoi(argv[++i]);
                if (size >= 16 && size <= 256)
                    custom_size = size;
                else
                {
                    std::cout << "Size must be between 16 and 256, using default 64." << std::endl;
                }
            }
            else if (!strcmp(argv[i], "-h") )
            {
                usage(argv);
                exit(0);
            }
            else { usage(argv); exit(0); }
        }//end if argc
    }
    else
    {
        usage(argv);
        exit(0);
    }
}

void WMWindowDock::filesGetter()
{
    // GIF muss direkt eine Datei sein
    if (checkIfDirectory(filename))
    {
        exit(1);
    }
}

void WMWindowDock::openXup(int argc, char **argv)
{
    char *displayName = NULL;

     // Open display
    if ((mDisplay = XOpenDisplay(displayName)) == NULL)
    {
      exit(0);
    }

    // Get root window
    mRoot = RootWindow(mDisplay, DefaultScreen(mDisplay));

    // Use custom size if set, otherwise use default 64
    int size = (custom_size > 0) ? custom_size : 64;

    // Create windows
    mAppWin = XCreateSimpleWindow(mDisplay, mRoot, 1, 1, size, size, 1, 1 , 0);
    mIconWin = XCreateSimpleWindow(mDisplay, mAppWin, 0, 0, size, size, 0, 0, 0);
    gc=XCreateGC(mDisplay, mIconWin, 0,0);
    //create display pixmap
    screen = XDefaultScreen(mDisplay);
    depth = DefaultDepth(mDisplay,screen );
    pix = XCreatePixmap(mDisplay, mRoot, size, size, depth);

    // Set classhint
    classHint.res_name =  const_cast<char*>(wInstanceName);
    classHint.res_class = const_cast<char*>(wClassName);
    XSetClassHint(mDisplay, mAppWin, &classHint);

    XSelectInput(mDisplay, mAppWin, ButtonPressMask | ExposureMask | ButtonReleaseMask |
            PointerMotionMask | StructureNotifyMask);
    XSelectInput(mDisplay, mIconWin, ButtonPressMask | ExposureMask | ButtonReleaseMask |
            PointerMotionMask | StructureNotifyMask );

    // Create delete atom
    deleteWindow = XInternAtom(mDisplay, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(mDisplay, mAppWin, &deleteWindow, 1);
    XSetWMProtocols(mDisplay, mIconWin, &deleteWindow, 1);

    // Set windowname
    XStoreName(mDisplay, mAppWin, APPNAME);
    XSetIconName(mDisplay, mAppWin, APPNAME);

    // Set sizehints
    sizeHints.flags = USSize  | USPosition;
    sizeHints.x = 0;
    sizeHints.y = 0;
    XSetWMNormalHints(mDisplay, mAppWin, &sizeHints);

    // Set wmhints
    wmHints.initial_state = WithdrawnState;
    wmHints.icon_window = mIconWin;
    wmHints.icon_x = 0;
    wmHints.icon_y = 0;
    wmHints.window_group = mAppWin;
    wmHints.flags = StateHint | IconWindowHint | WindowGroupHint | IconPositionHint ;
    XSetWMHints(mDisplay, mAppWin, &wmHints);

    // Set command
    XSetCommand(mDisplay, mAppWin, argv, argc);
    XMapWindow(mDisplay, mAppWin);
    XMapWindow(mDisplay, mIconWin);
    XClearWindow(mDisplay,mAppWin);
    XClearWindow (mDisplay,mIconWin);
    XFlush (mDisplay);
}

// Optimierte Pixel-Konvertierung
inline void convert_rgba_to_argb(const unsigned char *src, uint32_t *dst, size_t pixels)
{
    for (size_t i = 0; i < pixels; i++)
    {
        uint32_t r = src[i * 4 + 0];
        uint32_t g = src[i * 4 + 1];
        uint32_t b = src[i * 4 + 2];
        uint32_t a = src[i * 4 + 3];
        // premultiply
        r = (r * a) / 255;
        g = (g * a) / 255;
        b = (b * a) / 255;
        dst[i] = (a << 24) | (r << 16) | (g << 8) | b;
    }
}

void WMWindowDock::DisplayImage()
{
    std::string fpath = filename;
    int size = (custom_size > 0) ? custom_size : 64;

    // Initialize MagickWand
    MagickWandGenesis();
    MagickWand *mw = NewMagickWand();

    if (MagickReadImage(mw, fpath.c_str()) == MagickFalse)
    {
        DestroyMagickWand(mw);
        MagickWandTerminus();
        return;
    }

    MagickWand *coalesced = MagickCoalesceImages(mw);
    DestroyMagickWand(mw);
    mw = coalesced;

    size_t frame_count = MagickGetNumberImages(mw);

    if (frame_count == 0)
    {
        DestroyMagickWand(mw);
        MagickWandTerminus();
        return;
    }

    // FRAME CACHING: Lade alle Frames beim Start
    std::vector<CachedFrame> frames;

    for (size_t f = 0; f < frame_count; f++)
    {
        MagickSetIteratorIndex(mw, f);

        size_t width = MagickGetImageWidth(mw);
        size_t height = MagickGetImageHeight(mw);
        size_t delay = MagickGetImageDelay(mw);
        if (delay == 0)
            delay = 4;

        // Allocate und export pixels
        unsigned char *pixels = (unsigned char *)malloc(width * height * 4);
        if (!pixels)
            continue;

        if (MagickExportImagePixels(mw, 0, 0, width, height, "RGBA", CharPixel, pixels) == MagickFalse)
        {
            free(pixels);
            continue;
        }

        // Cache frame
        CachedFrame cf;
        cf.pixels = pixels;
        cf.width = width;
        cf.height = height;
        cf.delay = delay;
        frames.push_back(cf);
    }

    // Cleanup MagickWand - nicht mehr nötig
    DestroyMagickWand(mw);
    MagickWandTerminus();

    if (frames.empty())
        return;

    // Setup Imlib2 for rendering
    visual = DefaultVisual(mDisplay, DefaultScreen(mDisplay));
    Colormap cmap = DefaultColormap(mDisplay, DefaultScreen(mDisplay));

    imlib_context_set_display(mDisplay);
    imlib_context_set_visual(visual);
    imlib_context_set_colormap(cmap);
    imlib_context_set_dither(1);
    imlib_context_set_blend(0);
    imlib_context_set_anti_alias(0);

    // Pre-allocate scaled image
    Imlib_Image scaled = imlib_create_image(size, size);
    if (!scaled)
    {
        // Cleanup frames
        for (auto& f : frames)
            free(f.pixels);
        return;
    }

    // Animation loop - endlos, mit gecachten Frames
    while (true)
    {
        for (size_t frame_idx = 0; frame_idx < frames.size(); frame_idx++)
        {
            CachedFrame& cf = frames[frame_idx];

            // Create Imlib2 image from cached pixels
            Imlib_Image img = imlib_create_image(cf.width, cf.height);
            if (!img)
                continue;

            imlib_context_set_image(img);

            // Get pixel data pointer
            uint32_t *imlib_pixels = imlib_image_get_data();
            if (!imlib_pixels)
            {
                imlib_free_image();
                continue;
            }

            // Copy pixels
            convert_rgba_to_argb(cf.pixels, imlib_pixels, cf.width * cf.height);
            imlib_image_put_back_data(imlib_pixels);

            // Reuse scaled image
            imlib_context_set_image(scaled);
            imlib_blend_image_onto_image(img, 1, 0, 0, cf.width, cf.height, 0, 0, size, size);

            // Render
            imlib_context_set_drawable(pix);
            imlib_render_image_on_drawable_at_size(0, 0, size, size);

            // Update window
            XSetWindowBackgroundPixmap(mDisplay, mIconWin, pix);
            XClearWindow(mDisplay, mIconWin);
            XFlush(mDisplay);

            // Cleanup
            imlib_context_set_image(img);
            imlib_free_image();

            // Sleep
            unsigned long delay_ns = (unsigned long)(cf.delay * 10 * 1000 * 1000 * stime);
            struct timespec ts;
            ts.tv_sec = delay_ns / 1000000000;
            ts.tv_nsec = delay_ns % 1000000000;
            nanosleep(&ts, NULL);
        }
    }

    // Cleanup (unreachable - Endlosschleife oben; hier nur der Vollständigkeit halber)
    imlib_free_image();
    for (auto& f : frames)
        free(f.pixels);
}

void WMWindowDock::setBuffer(Imlib_Image im)
{
    buffer = im;
}

int WMWindowDock::load_err_image(std::string path)
{
    Imlib_Load_Error err;
    const char *fpath = path.c_str();
    image = imlib_load_image_with_error_return(fpath, &err);

    if (err)
        return 1;
    return 0;
}

void WMWindowDock::usage(char **argv)
{
    std::cout<<std::endl<<APPNAME<<" "<<VERSION<<std::endl<<std::endl
    <<"GIF Animation Player for Dock"<<std::endl<<std::endl
    <<argv[0]<<" -e <gif_file>     : Path to GIF file to play"<<std::endl
    <<argv[0]<<" -t <speed>        : Speed (0.5=2x faster, 1=normal, 2=2x slower)"<<std::endl
    <<argv[0]<<" -s <size>         : Window size in pixels (16-256, default 64)"<<std::endl
    <<argv[0]<<" -h                : Display this help"<<std::endl<<std::endl;
}