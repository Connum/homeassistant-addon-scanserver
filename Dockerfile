FROM ghcr.io/connum/debian-base-scansupport:7.7.0

LABEL io.hass.version="1.0" io.hass.type="addon" io.hass.arch="aarch64|amd64"

# Add env
ENV TERM="xterm-256color"

# Setup base
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        sane \
        sane-utils \
        sed \
        dbus \
        scanbd \
    # sane-scan-pdf dependencies
        bash \
        netpbm \
        ghostscript \
        poppler-utils \
        units \
        imagemagick \
        unpaper \
        util-linux \
        tesseract-ocr \
        tesseract-ocr-all \
        parallel \
        bc \
    # for debugging only
        nano \
    && mkdir -p /var/run/dbus/ \
    # sane-scan-pdf
    && git clone --branch master https://github.com/rocketraman/sane-scan-pdf.git /opt/sane-scan-pdf && \
        chmod a+x /opt/sane-scan-pdf/scan /opt/sane-scan-pdf/scan_perpage && \
        ln -s /opt/sane-scan-pdf/scan /usr/local/bin/sane-scan-pdf \
    # patch sane-scan-pdf script
    && sed -i 's|\${XDG_DATA_HOME:-\$HOME/.local/share}|/config|g' /opt/sane-scan-pdf/scan \
    && sed -i 's|"\$DIR/scan_perpage"|/opt/sane-scan-pdf/scan_perpage|g' /opt/sane-scan-pdf/scan \
    # add root user to scanner group
    && usermod -a -G scanner root \
    # cleanup
    && apt-get remove --purge -y \
        git \
    && apt-get autoremove -y

# Copy root filesystem
COPY rootfs /

RUN chmod a+x /run.sh /setup.sh \
    && . /setup.sh \
    && rm /setup.sh

CMD ["/run.sh"]
