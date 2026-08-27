#include <iostream>
#include <cstdlib>
#include <unistd.h>
#include <X11/Xlib.h>

#include "wmgifdock.hpp"
#include "imagefiles.hpp"

int main(int argc, char **argv)
{
    WMWindowDock doc;

    doc.parseCmLine(argc, argv);
    doc.filesGetter();
    doc.openXup(argc, argv);
    doc.DisplayImage();

    return 0;
}
