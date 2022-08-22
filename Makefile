VERSION = MODWAVE_0.3beta2

FLAGS = -Wall -Wextra -Wno-unused-parameter -g -Wno-unused -O3 -ffast-math \
	-DVERSION=$(VERSION) -DPFFFT_SIMD_DISABLE \
	-I. -Iext -Iext/imgui -Idep/build/include -Idep/include -Idep/build/include/SDL2 -Idep/include/SDL2
CFLAGS +=
CXXFLAGS += -std=c++11
LDFLAGS +=
DISTSUFFIX =

SOURCES = \
	ext/pffft/pffft.c \
	ext/lodepng/lodepng.cpp \
	ext/imgui/imgui.cpp \
	ext/imgui/imgui_draw.cpp \
	ext/imgui/imgui_demo.cpp \
	ext/imgui/examples/sdl_opengl2_example/imgui_impl_sdl.cpp \
	$(wildcard src/*.cpp)


# OS-specific
include Makefile-arch.inc

DEP_PRODUCTS = dep
LIBDIR = $(DEP_PRODUCTS)/lib

ifeq ($(ARCH),lin)
	# Linux
	FLAGS += -DARCH_LIN $(shell pkg-config --cflags gtk+-2.0)
	LDFLAGS += -static-libstdc++ -static-libgcc \
		-lGL -lpthread \
		-L$(LIBDIR) -lSDL2 -lsamplerate -lsndfile -ljansson -lcurl \
		-lgtk-x11-2.0 -lgobject-2.0
	SOURCES += ext/osdialog/osdialog_gtk2.c
else ifeq ($(ARCH),mac)
	# Mac
	ifneq ($(MAKECMDGOALS),universal)
		ifeq ($(BUILDARCH),universal)
			CFLAGS += -arch x86_64 -arch arm64
			CXXFLAGS += -arch x86_64 -arch arm64
			LDFLAGS += -arch x86_64 -arch arm64
			DISTSUFFIX =
			DEP_PRODUCTS = dep/build
		else ifeq ($(BUILDARCH),arm64)
			CFLAGS += -arch arm64
			CXXFLAGS += -arch arm64
			LDFLAGS += -arch arm64
			DISTSUFFIX = _arm64
			DEP_PRODUCTS = dep/build_arm64
		else
			CFLAGS += -arch x86_64
			CXXFLAGS += -arch x86_64
			LDFLAGS += -arch x86_64
			DISTSUFFIX = _x86_64
			DEP_PRODUCTS = dep/build_x86_64
		endif
		LIBDIR = $(DEP_PRODUCTS)/lib
		FLAGS += -DARCH_MAC \
			-mmacosx-version-min=10.11
		CXXFLAGS += -stdlib=libc++
		LDFLAGS += -mmacosx-version-min=10.11 \
			-stdlib=libc++ -lpthread \
			-framework Cocoa -framework OpenGL -framework IOKit -framework CoreVideo \
			-L$(LIBDIR) -lSDL2 -lsamplerate -lsndfile -ljansson -lcurl
		SOURCES += ext/osdialog/osdialog_mac.m
	endif
else ifeq ($(ARCH),win)
	# Windows
	FLAGS += -DARCH_WIN
	LDFLAGS += \
		-L$(LIBDIR) -lmingw32 -lSDL2main -lSDL2 -lsamplerate -lsndfile -ljansson -lcurl \
		-lopengl32 -mwindows
	SOURCES += ext/osdialog/osdialog_win.c
	OBJECTS += info.o
info.o: info.rc
	windres $^ $@
endif


.DEFAULT_GOAL := build
build: WaveEdit

run: WaveEdit
	LD_LIBRARY_PATH=$(LIBDIR) ./WaveEdit

debug: WaveEdit
ifeq ($(ARCH),mac)
	lldb ./WaveEdit
else
	gdb -ex 'run' ./WaveEdit
endif


OBJECTS += $(SOURCES:%=build/%.o)


WaveEdit: $(OBJECTS)
	$(CXX) -o $@ $^ $(LDFLAGS)

clean:
	rm -frv $(OBJECTS) WaveEdit dist$(DISTSUFFIX)

.PHONY: dist
dist: WaveEdit
	mkdir -p dist$(DISTSUFFIX)/WaveEdit
	cp -R banks dist$(DISTSUFFIX)/WaveEdit
	cp LICENSE* dist$(DISTSUFFIX)/WaveEdit
	cp doc/manual.pdf dist$(DISTSUFFIX)/WaveEdit
	cp releasenotes.txt dist$(DISTSUFFIX)/WaveEdit
ifeq ($(ARCH),lin)
	cp -R logo*.png header.eps fonts catalog dist/WaveEdit
	cp WaveEdit WaveEdit.sh dist/WaveEdit
	cp $(LIBDIR)/libSDL2-2.0.so.0 dist/WaveEdit
	cp $(LIBDIR)/libsamplerate.so.0 dist/WaveEdit
	cp $(LIBDIR)/libsndfile.so.1 dist/WaveEdit
	cp $(LIBDIR)/libjansson.so.4 dist/WaveEdit
	cp $(LIBDIR)/libcurl.so.4 dist/WaveEdit
else ifeq ($(ARCH),mac)
	mkdir -p dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/MacOS
	mkdir -p dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/Resources
	cp Info.plist dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents
	cp WaveEdit dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/MacOS
	cp -R logo*.png logo.icns header.eps fonts catalog dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/Resources
	# Remap dylibs in executable
	otool -L dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/MacOS/WaveEdit
	cp $(LIBDIR)/libSDL2-2.0.0.dylib dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/MacOS
	install_name_tool -change $(PWD)/$(LIBDIR)/libSDL2-2.0.0.dylib @executable_path/libSDL2-2.0.0.dylib dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/MacOS/WaveEdit
	cp $(LIBDIR)/libsamplerate.0.dylib dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/MacOS
	install_name_tool -change $(PWD)/$(LIBDIR)/libsamplerate.0.dylib @executable_path/libsamplerate.0.dylib dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/MacOS/WaveEdit
	cp $(LIBDIR)/libsndfile.1.dylib dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/MacOS
	install_name_tool -change $(PWD)/$(LIBDIR)/libsndfile.1.dylib @executable_path/libsndfile.1.dylib dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/MacOS/WaveEdit
	cp $(LIBDIR)/libjansson.4.dylib dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/MacOS
	install_name_tool -change $(PWD)/$(LIBDIR)/libjansson.4.dylib @executable_path/libjansson.4.dylib dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/MacOS/WaveEdit
	cp $(LIBDIR)/libcurl.4.dylib dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/MacOS
	install_name_tool -change $(PWD)/$(LIBDIR)/libcurl.4.dylib @executable_path/libcurl.4.dylib dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/MacOS/WaveEdit
	otool -L dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app/Contents/MacOS/WaveEdit
	codesign --force --deep -s - dist$(DISTSUFFIX)/WaveEdit/WaveEdit.app
else ifeq ($(ARCH),win)
	cp -R logo*.png header.eps fonts catalog dist/WaveEdit
	cp WaveEdit.exe dist/WaveEdit
	cp /mingw32/bin/libgcc_s_dw2-1.dll dist/WaveEdit
	cp /mingw32/bin/libwinpthread-1.dll dist/WaveEdit
	cp /mingw32/bin/libstdc++-6.dll dist/WaveEdit
	cp $(DEP_PRODUCTS)/bin/SDL2.dll dist/WaveEdit
	cp $(DEP_PRODUCTS)/bin/libsamplerate-0.dll dist/WaveEdit
	cp $(DEP_PRODUCTS)/bin/libsndfile-1.dll dist/WaveEdit
	cp $(DEP_PRODUCTS)/bin/libjansson-4.dll dist/WaveEdit
	cp $(DEP_PRODUCTS)/bin/libcurl-4.dll dist/WaveEdit
endif
	cd dist$(DISTSUFFIX) && zip -9 -r WaveEdit-$(VERSION)-$(ARCH)$(DISTSUFFIX).zip WaveEdit

# SUFFIXES:

build/%.c.o: %.c
	@mkdir -p $(@D)
	$(CC) $(FLAGS) $(CFLAGS) -c -o $@ $<

build/%.cpp.o: %.cpp
	@mkdir -p $(@D)
	$(CXX) $(FLAGS) $(CXXFLAGS) -c -o $@ $<

build/%.m.o: %.m
	@mkdir -p $(@D)
	$(CC) $(FLAGS) $(CFLAGS) -c -o $@ $<

.PHONY: universal

universal:
	export BUILDARCH=universal && $(MAKE) clean && $(MAKE) && $(MAKE) dist
