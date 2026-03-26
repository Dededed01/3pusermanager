FROM alpine:3.19 AS builder
RUN apk add --no-cache gcc make musl-dev linux-headers wget
WORKDIR /build
RUN wget -qO- https://github.com/3proxy/3proxy/archive/refs/tags/0.9.4.tar.gz | tar xz && \
    cd 3proxy-0.9.4 && \
    make -f Makefile.Linux

FROM alpine:3.19
COPY --from=builder /build/3proxy-0.9.4/bin/3proxy /usr/local/bin/3proxy
RUN mkdir -p /etc/3proxy /var/log/3proxy
ENTRYPOINT ["3proxy", "/etc/3proxy/3proxy.cfg"]
