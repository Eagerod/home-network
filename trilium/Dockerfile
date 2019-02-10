FROM ncfgbase

RUN curl -sSL https://deb.nodesource.com/setup_10.x | bash -

RUN \
    apt-get update -y && \
    apt-get install -y \
        nodejs

# Installation process expects a `node` executable on the system path
# RUN ln -s $(which nodejs) /usr/bin/node

ENV TRILIUM_VER 0.28.3
RUN \
    curl -sSL https://github.com/zadam/trilium/archive/v${TRILIUM_VER}.zip -o trilium.zip && \
    unzip trilium.zip && \
    rm trilium.zip

WORKDIR trilium-${TRILIUM_VER}

RUN npm install

# Copied from https://github.com/zadam/trilium/blob/v0.28.3/bin/build-server.sh
# Needed for sqlite dependency to be where expected.
RUN rm -r node_modules/electron* && \
    rm -r node_modules/sqlite3/lib/binding/* && \
    cp -r bin/deps/linux-x64/sqlite/node* node_modules/sqlite3/lib/binding/

ENV TRILIUM_DATA_DIR /var/lib/trilium/

CMD ["node", "src/www"]
