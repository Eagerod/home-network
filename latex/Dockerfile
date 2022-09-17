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
    apt-get clean

RUN \
    apt-get update && \
    apt-get install -y \
        texlive-pictures \
        texlive-pstricks && \
    apt-get clean

# tlmgr needs curl to do its downloads.
RUN apt-get update && \
    apt-get install -y curl && \
    apt-get clean

# RUN tlmgr option repository ftp://tug.org/historic/systems/texlive/2018/tlnet-final
RUN \
    tlmgr init-usertree && \
    tlmgr option repository ftp://ftp.math.utah.edu/pub/tex/historic/systems/texlive/2018/tlnet-final && \
    tlmgr update -v --all

RUN apt-get update && \
    apt-get install -y \
        python3-pip && \
    apt-get clean

RUN \
    groupadd latex && \
    useradd -rm -u 1000 -g latex latex

RUN \
    curl -fsSL https://www.downloadfonts.io/wp-content/uploads/2018/12/calibri-font-sv.zip -o calibri.zip && \
    unzip calibri.zip -d Calibri && \
    find Calibri -type f -iname "*.zip" -exec unzip "{}" -d /usr/local/share/fonts/ \; && \
    rm -rf Calibri calibri.zip

USER latex

RUN \
    mktexlsr && \
    luaotfload-tool -u

# Ok, now add the server thing
WORKDIR /app

COPY requirements.txt .

RUN pip3 install -r requirements.txt

COPY server.py .

RUN python3 -m flake8 .

ENTRYPOINT ["python3", "server.py"]
