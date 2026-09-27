ARG ALPINE_VER=3.24

FROM alpine:${ALPINE_VER} AS download

ARG TARGETARCH

RUN apk add --no-cache curl libgcc libstdc++

WORKDIR /download

COPY versions.env checksums.txt ./
COPY scripts/download.sh ./

RUN ./download.sh

COPY dist/ /dist/
COPY licenses/ /dist/licenses/

RUN chmod -R a+rX /dist

FROM alpine:${ALPINE_VER}

COPY --from=download /dist /usr/share/wodby-agents
COPY bin/wodby-agents-install /usr/local/bin/wodby-agents-install

USER 1000

ENTRYPOINT ["/usr/local/bin/wodby-agents-install"]
CMD ["/opt/wodby/agents"]
