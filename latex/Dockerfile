FROM debian:10

# A bunch of layers, just to keep them small.
# Helps for low memory registries.
RUN \
    apt-get update && \
    apt-get install -y texlive && \
    apt-get clean

RUN \
    apt-get update && \
    apt-get install -y 'texlive-latex-*' && \
    apt-get clean

RUN \
    apt-get update && \
    apt-get install -y \
        texlive-luatex \
        texlive-xetex && \
    apt-get clean

RUN \
    apt-get update && \
    apt-get install -y \
        texlive-fonts-extra && \
    apt-get clean && \
    mktexlsr && \
    luaotfload-tool -u

RUN \
    apt-get update && \
    apt-get install -y \
        texlive-pictures \
        texlive-pstricks && \
    apt-get clean

RUN apt-get update && \
    apt-get install -y \
        curl \
        make \
        vim \
        wget && \
    apt-get clean

RUN \
    curl -fsSL https://www.fontdload.com/fp02 -o calibri.zip && \
    unzip calibri.zip -d Calibri && \
    find Calibri -type f -iname "*.zip" -exec unzip "{}" -d /usr/local/share/fonts/ \; && \
    mktexlsr && \
    luaotfload-tool -u

# RUN tlmgr option repository ftp://tug.org/historic/systems/texlive/2018/tlnet-final
RUN \
    tlmgr init-usertree && \
    tlmgr option repository ftp://ftp.math.utah.edu/pub/tex/historic/systems/texlive/2018/tlnet-final && \
    tlmgr update -v --all

RUN \
    groupadd latex && \
    useradd -rm -u 1000 -g latex latex

USER latex

# RUN \
#     mktexlsr && \
#     luaotfload-tool -u
