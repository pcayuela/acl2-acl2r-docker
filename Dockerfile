# syntax=docker/dockerfile:1
#
# ACL2 and ACL2(r) 8.7 side by side, with the community books that the
# author's verification projects need already certified, so nothing has to
# be recertified after pulling the image.
#
#   /opt/acl2   plain ACL2   (saved_acl2,  books certified for arithmetic-5/top)
#   /opt/acl2r  ACL2(r)      (saved_acl2r, books certified for nonstd/nsa/trig,
#                             nsa and the reid-gamboa-differentiator support books)
#
# Plain-ACL2 and ACL2(r) certificates are mutually incompatible, so each
# flavor has its own books tree.
#
# Build:  docker build -t acl2-pcayuela .
# Test:   ./test.sh acl2-pcayuela

FROM ubuntu:24.04 AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl git m4 perl time \
        sbcl wget bzip2 libzstd-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# --- SBCL, built from source (the version ACL2 was developed against here) ---
FROM base AS sbcl
ARG SBCL_VERSION=2.6.5
RUN mkdir /build-sbcl && cd /build-sbcl \
    && wget -q "https://github.com/sbcl/sbcl/archive/refs/tags/sbcl-${SBCL_VERSION}.tar.gz" -O sbcl.tgz \
    && tar -xzf sbcl.tgz --strip-components=1 \
    && echo "\"${SBCL_VERSION}\"" > version.lisp-expr \
    && sh make.sh --fancy --prefix=/usr/local \
    && sh install.sh \
    && cd / && rm -rf /build-sbcl

# --- ACL2 sources at a pinned commit ---
FROM base AS src
ARG ACL2_COMMIT=4cab4f162b44fd6f01b8a3fb2e3d39be57ee2a3f
RUN git clone https://github.com/acl2/acl2.git /opt/acl2 \
    && cd /opt/acl2 && git checkout "${ACL2_COMMIT}" && rm -rf .git

# --- plain ACL2 ---
FROM base AS acl2-plain
ARG ACL2_COMMIT=4cab4f162b44fd6f01b8a3fb2e3d39be57ee2a3f
# .git is removed from the source stage, so tell the ACL2 build which commit this is
ENV ACL2_SNAPSHOT_INFO="git commit ${ACL2_COMMIT}"
COPY --from=sbcl /usr/local /usr/local
COPY --from=src /opt/acl2 /opt/acl2
ARG JOBS=4
ARG PLAIN_BOOKS="arithmetic-5/top"
RUN cd /opt/acl2 && make LISP=sbcl || { cat make.log; exit 1; }
RUN cd /opt/acl2/books && make ACL2=/opt/acl2/saved_acl2 build/Makefile-features \
    && build/cert.pl --acl2 /opt/acl2/saved_acl2 -j ${JOBS} ${PLAIN_BOOKS}

# --- ACL2(r) ---
FROM base AS acl2-real
ARG ACL2_COMMIT=4cab4f162b44fd6f01b8a3fb2e3d39be57ee2a3f
ENV ACL2_SNAPSHOT_INFO="git commit ${ACL2_COMMIT}"
COPY --from=sbcl /usr/local /usr/local
COPY --from=src /opt/acl2 /opt/acl2r
ARG JOBS=4
ARG REAL_BOOKS="arithmetic-5/top nonstd/nsa/nsa nonstd/nsa/trig nonstd/workshops/2011/reid-gamboa-differentiator/support/exp-minimal nonstd/workshops/2011/reid-gamboa-differentiator/support/differentiator"
RUN cd /opt/acl2r && make large-acl2r LISP=sbcl || { cat make.log; exit 1; }
RUN cd /opt/acl2r/books && make ACL2=/opt/acl2r/saved_acl2r build/Makefile-features \
    && build/cert.pl --acl2 /opt/acl2r/saved_acl2r -j ${JOBS} ${REAL_BOOKS}

# --- final image ---
FROM base AS final
COPY --from=sbcl /usr/local /usr/local
COPY --from=acl2-plain /opt/acl2 /opt/acl2
COPY --from=acl2-real /opt/acl2r /opt/acl2r
RUN ln -s /opt/acl2/saved_acl2 /usr/local/bin/acl2 \
    && ln -s /opt/acl2r/saved_acl2r /usr/local/bin/acl2r
WORKDIR /work
CMD ["bash"]
