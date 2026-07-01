FROM emscripten/emsdk:5.0.7 AS builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      bzip2 make bc xxd patch \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ARG VERSION=1.38.0
ENV VERSION=${VERSION}
ENV DIRECTORY=busybox-${VERSION}
ENV OUT_DIR=/out
ENV ROOT=/src

WORKDIR /src

ADD https://busybox.net/downloads/busybox-${VERSION}.tar.bz2 ${DIRECTORY}.tar.bz2
RUN echo "34f9ea6ff8636f2c9241153b9114eefa9e65674a45318ae1ef95bb5f31c53bb2  ${DIRECTORY}.tar.bz2" | sha256sum -c - \
    && tar -xjf ${DIRECTORY}.tar.bz2 && rm ${DIRECTORY}.tar.bz2

WORKDIR /src/${DIRECTORY}
RUN mkdir -p $OUT_DIR

COPY config ./config
COPY scripts ./scripts-overlay
RUN chmod +x scripts-overlay/apply-config.sh \
    && make allnoconfig \
    && ./scripts-overlay/apply-config.sh config/sandbox.config

COPY js ./js

ENV CFLAGS="\
    -O2 \
    -Wno-error \
    -Wno-error=implicit-function-declaration \
    -Wno-error=implicit-int \
    -Wno-error=int-conversion \
    -Wno-error=incompatible-pointer-types \
    -Wno-error=deprecated-non-prototype \
    -Wno-error=strict-prototypes \
"

ENV BUSYBOX_LDFLAGS=" \
    -lnodefs.js -lworkerfs.js \
    --post-js /src/busybox-${VERSION}/js/post.js \
    -s WASM_BIGINT=1 \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s STACK_SIZE=2097152 \
    -s EXIT_RUNTIME=0 \
    -s ERROR_ON_UNDEFINED_SYMBOLS=0 \
    -s EXPORTED_RUNTIME_METHODS=callMain,FS,NODEFS,WORKERFS,ENV \
    -s INCOMING_MODULE_JS_API=noInitialRun,wasmBinary,locateFile,preRun,postRun,instantiateWasm,print,printErr,arguments,thisProgram \
    -s INVOKE_RUN=0 \
    -s MODULARIZE=1 \
    -s EXPORT_ES6=1 \
"

RUN make V=1 \
        CC=emcc \
        CXX=em++ \
        LD="emcc -nostdlib" \
        AR=emar \
        NM=emnm \
        RANLIB=emranlib \
        STRIP=true \
        OBJCOPY=true \
        OBJDUMP=true \
        HOSTCC=gcc \
        CROSS_COMPILE="" \
        SKIP_STRIP=y \
        EXTRA_CFLAGS="${CFLAGS}" \
        EXTRA_LDFLAGS="${BUSYBOX_LDFLAGS}" \
        -j$(nproc) busybox_unstripped

RUN test -f busybox_unstripped \
    && test -f busybox_unstripped.wasm \
    && mv busybox_unstripped busybox.mjs \
    && mv busybox_unstripped.wasm busybox.wasm \
    && sed -i 's|busybox_unstripped\.wasm|busybox.wasm|g' busybox.mjs \
    && grep -q 'export default' busybox.mjs

RUN mkdir -p /dist \
    && cp busybox.mjs /dist/busybox.mjs \
    && cp busybox.wasm /dist/busybox.wasm \
    && ls -la /dist/ \
    && magic=$(head -c4 /dist/busybox.wasm | od -An -tx1 | tr -d ' \n') \
    && echo "wasm magic: $magic" \
    && [ "$magic" = "0061736d" ] \
    && size=$(stat -c%s /dist/busybox.wasm) \
    && echo "wasm size: $size" \
    && [ "$size" -gt 102400 ] \
    && grep -q 'export default' /dist/busybox.mjs

FROM scratch AS exportor
COPY --from=builder /dist /dist
