FROM ncfgbase

RUN curl -sSL https://deb.nodesource.com/setup_6.x | bash -
RUN \
    apt-get update -y && \
    apt-get install -y \
        build-essential \
        wget \
        nodejs \
        time \
        imagemagick \
        optipng \
        strace \
        nginx \
        git \
        python \
        zlib1g-dev \
        libpcre3-dev \
        aspell \
        aspell-en \
        autoconf

# Note, there was a problem with qpdf 6.0.0 release that caused from-source 
#   installations to fail. Because of this, instead of installing from source,
#   this is downloaded from the release. The command to download the source
#   is left here in case we upgrade to qpdf > 6.0.0, as the fix seems to have
#   been merged immediately after.
# https://github.com/qpdf/qpdf/issues/61
# 
ENV QPDF_VERSION release-qpdf-6.0.0
# RUN git clone --branch ${QPDF_VERSION} --single-branch https://github.com/qpdf/qpdf /var/lib/qpdf
RUN \
    curl -sSL https://github.com/qpdf/qpdf/archive/$QPDF_VERSION.tar.gz -o /tmp/$QPDF_VERSION.tar.gz && \
    tar -C /tmp/ -xzf /tmp/$QPDF_VERSION.tar.gz

WORKDIR /tmp/qpdf-$QPDF_VERSION
RUN apt-get install -y xsltproc

RUN ./autogen.sh && ./configure

# Create some garbage files that the build process desires. Since this is all
#   running out of a container, docs are pretty useless.
RUN mkdir -p manual/build && touch manual/build/qpdf-manual.html doc/qpdf-manual.html doc/qpdf-manual.pdf
#RUN sed -i 's/BUILD_HTML=.*/BUILD_HTML=1/g' autoconf.mk

# For some reason this file is malformed, and is self-referential at line 5. 
#   Just drop line 5 and hope for the best? :D
#RUN sed -i '5d' manual/html.xsl
RUN make && make install && ldconfig

# RUN git clone --branch master --single-branch https://github.com/sharelatex/sharelatex /var/lib/sharelatex
