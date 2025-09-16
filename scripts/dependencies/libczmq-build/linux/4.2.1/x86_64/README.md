# libczmq v4.2.1

## Dependency

1. libnss, libnspr
```sh 
sudo apt install -y libnss3-dev libnspr4-dev pkg-config
```

2. doc, graphviz (for doc)

```sh
sudo apt-get install doxygen graphviz
```

## My compiler info
```sh
gcc -v
```
```
Using built-in specs.
COLLECT_GCC=gcc
COLLECT_LTO_WRAPPER=/usr/libexec/gcc/x86_64-linux-gnu/14/lto-wrapper
OFFLOAD_TARGET_NAMES=nvptx-none:amdgcn-amdhsa
OFFLOAD_TARGET_DEFAULT=1
Target: x86_64-linux-gnu
Configured with: ../src/configure -v --with-pkgversion='Ubuntu 14.2.0-19ubuntu2' --with-bugurl=file:///usr/share/doc/gcc-14/README.Bugs --enable-languages=c,ada,c++,go,d,fortran,objc,obj-c++,m2,rust --prefix=/usr --with-gcc-major-version-only --program-suffix=-14 --program-prefix=x86_64-linux-gnu- --enable-shared --enable-linker-build-id --libexecdir=/usr/libexec --without-included-gettext --enable-threads=posix --libdir=/usr/lib --enable-nls --enable-bootstrap --enable-clocale=gnu --enable-libstdcxx-debug --enable-libstdcxx-time=yes --with-default-libstdcxx-abi=new --enable-libstdcxx-backtrace --enable-gnu-unique-object --disable-vtable-verify --enable-plugin --enable-default-pie --with-system-zlib --enable-libphobos-checking=release --with-target-system-zlib=auto --enable-objc-gc=auto --enable-multiarch --disable-werror --enable-cet --with-arch-32=i686 --with-abi=m64 --with-multilib-list=m32,m64,mx32 --enable-multilib --with-tune=generic --enable-offload-targets=nvptx-none=/build/gcc-14-C86vgL/gcc-14-14.2.0/debian/tmp-nvptx/usr,amdgcn-amdhsa=/build/gcc-14-C86vgL/gcc-14-14.2.0/debian/tmp-gcn/usr --enable-offload-defaulted --without-cuda-driver --enable-checking=release --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu --with-build-config=bootstrap-lto-lean --enable-link-serialization=2
Thread model: posix
Supported LTO compression algorithms: zlib zstd
gcc version 14.2.0 (Ubuntu 14.2.0-19ubuntu2)
```

## Build step commands

1. Download libusb v1.0.29 source code
2. Open terminal

3. Run cmake
```sh
cmake .. -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="/home/d-moskovskikh/aes-source/libczmq-build/linux/4.2.1/x86_64/" -DLIBZMQ_INCLUDE_DIRS="/home/d-moskovskikh/aes-source/libzmq-build/linux/4.3.5/x86_64/include/" -DLIBZMQ_LIBRARIES="/home/d-moskovskikh/aes-source/libzmq-build/linux/4.3.5/x86_64/lib/libzmq.so" -DCMAKE_C_FLAGS="-D_GNU_SOURCE" -DCMAKE_BUILD_TYPE="RelWithDebInfo"
```

4. Build library
```sh
make
```

5. Install library

> WARNING! WRITE YOUR DESTDIR

```sh
make install
```

## Using

