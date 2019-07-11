FROM alpine

RUN apk add ca-certificates curl git git-lfs gnupg util-linux

COPY git-sync.sh /
RUN chmod +x /git-sync.sh

ENTRYPOINT ["/git-sync.sh"]
CMD []
