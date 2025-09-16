#!/bin/sh

sudo tee /etc/ld.so.conf.d/100-srsran-ld.conf > /dev/null <<EOF
    /var/srs_libs/libczmq-build/linux/4.2.1/x86_64/lib
    /var/srs_libs/libsrsgui-build/linux/2.0/x86_64/lib  
    /var/srs_libs/libzmq-build/linux/4.3.5/x86_64/lib
EOF

sudo ldconfig