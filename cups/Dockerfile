FROM ghcr.io/home-assistant/base:latest

# Add env
ENV LANG=C.UTF-8
# Set CUPS environment variables for data persistence (HA shared directory)
ENV CUPS_DATADIR=/share/cups
ENV CUPS_CACHEDIR=/share/cups/cache
ENV CUPS_LOGDIR=/share/cups/logs
ENV CUPS_STATEDIR=/share/cups/state
ENV CUPS_SERVERROOT=/share/cups/config

# Setup base
# Note: hplip, foomatic-db, and foomatic-db-ppds were removed from Alpine 3.23
# and are no longer available in stable repositories.
# Gutenprint covers most printer models as a replacement.
# Alpine splits this: `gutenprint` is libraries/tools only; `gutenprint-cups`
# ships rastertogutenprint and the CUPS PPDs (Canon, HP, Brother, etc.).
RUN echo "http://dl-cdn.alpinelinux.org/alpine/v$(cat /etc/alpine-release | cut -d'.' -f1,2)/main" > /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/v$(cat /etc/alpine-release | cut -d'.' -f1,2)/community" >> /etc/apk/repositories && \
    apk update && \
    apk add --no-cache \
        cups \
        cups-filters \
        ghostscript \
        libjpeg-turbo \
        net-snmp \
        epson-inkjet-printer-escpr \
        gutenprint \
        gutenprint-cups \
        avahi \
        dbus \
        gcompat \
        libstdc++ \
        jq \
        bash \
        which \
        build-base \
        fribidi-dev \
        git \
        make \
        bc \
        cups-dev \
        libusb-dev && \
    git clone https://github.com/OpenPrinting/foo2zjs.git /tmp/foo2zjs && \
    cd /tmp/foo2zjs && \
    sed -i 's/#include <sys\/cdefs.h>//g' *.[ch] 2>/dev/null || true && \
    cd jbigkit && \
    make lib && \
    cd .. && \
    # Compile all printer filter engines and decoders
    make CFLAGS="-O2 -D_GNU_SOURCE -I./jbigkit/libjbig" LDFLAGS="-L./jbigkit/libjbig" \
        all-test && \
    # Install all binaries and wrappers to /usr/bin
    install -c -m 755 foo2zjs foo2hp foo2xqx foo2lava foo2qpdl foo2slx foo2hiperc foo2hbpl2 foo2oak /usr/bin/ && \
    install -c -m 755 foo2*-wrapper /usr/bin/ && \
    install -c -m 755 *decode /usr/bin/ 2>/dev/null || true && \
    # Install all ICM color profiles
    mkdir -p /usr/share/foo2zjs/icm /usr/share/foo2hbpl2/icm /usr/share/foo2hp/icm /usr/share/foo2qpdl/icm && \
    cp -r icm/* /usr/share/foo2zjs/icm/ 2>/dev/null || true && \
    cp -r icm/* /usr/share/foo2hbpl2/icm/ 2>/dev/null || true && \
    cp -r icm/* /usr/share/foo2hp/icm/ 2>/dev/null || true && \
    cp -r icm/* /usr/share/foo2qpdl/icm/ 2>/dev/null || true && \
    # Install every PPD into CUPS model directory
    mkdir -p /usr/share/cups/model && \
    find PPD -type f -name "*.ppd" -exec cp {} /usr/share/cups/model/ \; && \
    cd / && \
    rm -rf /tmp/foo2zjs && \
    apk del build-base git make bc which cups-dev libusb-dev

# Build and install the Dymo CUPS drivers (LabelWriter/LabelManager). The
# Dymo PPDs (e.g. lw4xl.ppd for the LabelWriter 4XL) reference
# /usr/lib/cups/filter/raster2dymolw; the filter is proprietary and not
# available in the Alpine repositories, so compile the vendored GPLv2
# dymo-cups-drivers source and install it (filters raster2dymolw and
# raster2dymolm plus the official Dymo PPDs).
COPY dymo-cups-drivers /tmp/dymo-cups-drivers
RUN \
    apk add --no-cache --virtual .dymo-build \
        g++ \
        make \
        cups-dev && \
    cd /tmp/dymo-cups-drivers && \
    find . -exec touch -t 202001010000 {} + && \
    ./configure && \
    make && \
    make install && \
    cd / && \
    rm -rf /tmp/dymo-cups-drivers && \
    apk del .dymo-build

# Copy data
COPY rootfs /

# Expose CUPS web interface port
EXPOSE 631

HEALTHCHECK \
    CMD lpstat -r || exit 1
