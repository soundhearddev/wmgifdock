#
# wmgifdock Makefile
#
PREFIX = /usr
DESTDIR = # Left BLANK to make it void and NULL
CXX=g++
CXXFLAGS += -Wall -std=c++11 -O2
CXXFLAGS += $(shell pkg-config --cflags MagickWand)

LDFLAGS += -lXext -lXpm -lX11 -lImlib2
LDFLAGS += $(shell pkg-config --libs MagickWand)
LDFLAGS += -L$(shell dirname $(shell find /nix/store -name 'libboost_system.so' 2>/dev/null | head -1))
LDFLAGS += -lboost_system -lboost_filesystem

OBJECTS = imagefiles.o wmgifdock.o main.o

TARGET = wmgifdock

all: $(TARGET)
$(TARGET): $(OBJECTS)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(OBJECTS) $(LDFLAGS)
.PHONY:	install clean uninstall
install: all
	install -D -m 0755 $(TARGET) $(DESTDIR)$(PREFIX)/bin/$(TARGET)
clean:
	rm -f *~ *.o $(TARGET)
uninstall:
	rm $(PREFIX)/bin/$(TARGET)
# End of file
