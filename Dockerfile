FROM ubuntu:20.04 as ubuntu-builder
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Taipei

RUN apt-get update
RUN apt-get install -y git wget autoconf automake libtool make libreadline-dev texinfo pkg-config libpam0g-dev libjson-c-dev bison flex libc-ares-dev python3-dev python3-sphinx install-info build-essential libsnmp-dev perl protobuf-c-compiler libprotobuf-c-dev libcap-dev libelf-dev libunwind-dev libgrpc++-dev protobuf-compiler-grpc libsqlite3-dev libzmq5 libzmq3-dev cmake libpcre2-dev

RUN mkdir /src
RUN mkdir /app

WORKDIR /src
RUN cd /src
RUN wget https://ci1.netdef.org/artifact/LIBYANG-LIBYANG21/shared/build-13/Ubuntu-20.04-x86_64-Packages/libyang2_2.1.128-2%7Eubuntu20.04u2_amd64.deb
RUN wget https://ci1.netdef.org/artifact/LIBYANG-LIBYANG21/shared/build-13/Ubuntu-20.04-x86_64-Packages/libyang2-tools_2.1.128-2%7Eubuntu20.04u2_amd64.deb
RUN wget https://ci1.netdef.org/artifact/LIBYANG-LIBYANG21/shared/build-13/Ubuntu-20.04-x86_64-Packages/libyang2-dev_2.1.128-2%7Eubuntu20.04u2_amd64.deb
RUN wget https://ci1.netdef.org/artifact/LIBYANG-LIBYANG21/shared/build-13/Ubuntu-20.04-x86_64-Packages/libyang-tools_2.1.128-2%7Eubuntu20.04u2_all.deb

# libyang
RUN dpkg -i libyang2_2.1.128-2~ubuntu20.04u2_amd64.deb
RUN dpkg -i libyang2-tools_2.1.128-2~ubuntu20.04u2_amd64.deb
RUN dpkg -i libyang2-dev_2.1.128-2~ubuntu20.04u2_amd64.deb
RUN dpkg -i libyang-tools_2.1.128-2~ubuntu20.04u2_all.deb

# sysrepo
RUN mkdir /src/sysrepo
WORKDIR /src/sysrepo
RUN git clone https://github.com/sysrepo/sysrepo.git /src/sysrepo
RUN cd /src/sysrepo
RUN git checkout v2.2.105
RUN mkdir build; cd build
RUN cmake --install-prefix "/usr" -DCMAKE_BUILD_TYPE:String="Release" /src/sysrepo
RUN make && make install

# frr
RUN mkdir /src/frr
WORKDIR /src/frr
RUN git clone https://github.com/frrouting/frr.git /src/frr
RUN cd /src/frr
RUN git checkout frr-10.1.1
RUN ./bootstrap.sh
RUN ./configure \
    --prefix=/app \
    --includedir=\${prefix}/include \
    --bindir=\${prefix}/bin \
    --sbindir=\${prefix}/lib/frr \
    --libdir=\${prefix}/lib/frr \
    --libexecdir=\${prefix}/lib/frr \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --with-moduledir=\${prefix}/lib/frr/modules \
    --enable-configfile-mask=0640 \
    --enable-logfile-mask=0640 \
    --enable-snmp=agentx \
    --enable-multipath=64 \
    --enable-user=frr \
    --enable-group=frr \
    --enable-vty-group=frrvty \
    --enable-grpc \
	--enable-fpm \
    --enable-sysrepo \
    --with-pkg-git-version \
    --with-pkg-extra-version=-HaiyangFRRVersion
RUN make && make install

FROM ubuntu:20.04
RUN apt-get update
RUN apt-get install -y libcap-dev libunwind-dev libprotobuf-c-dev libjson-c-dev libreadline-dev
RUN mkdir /app
RUN mkdir -p /src/etc/frr
RUN mkdir /etc/frr
COPY --from=ubuntu-builder /app/ /app/
COPY --from=ubuntu-builder /src/frr/tools/etc/frr/ /src/etc/frr/

COPY --from=ubuntu-builder /src/libyang2_2.1.128-2~ubuntu20.04u2_amd64.deb /tmp/
COPY --from=ubuntu-builder /src/libyang2-tools_2.1.128-2~ubuntu20.04u2_amd64.deb /tmp/
COPY --from=ubuntu-builder /src/libyang-tools_2.1.128-2~ubuntu20.04u2_all.deb /tmp/
RUN dpkg -i /tmp/libyang2_2.1.128-2~ubuntu20.04u2_amd64.deb
RUN dpkg -i /tmp/libyang2-tools_2.1.128-2~ubuntu20.04u2_amd64.deb
RUN dpkg -i /tmp/libyang-tools_2.1.128-2~ubuntu20.04u2_all.deb
RUN rm -rf /tmp/*

RUN groupadd -r -g 92 frr
RUN groupadd -r -g 85 frrvty
RUN adduser --system --ingroup frr --home /var/run/frr/ \
   --gecos "FRR suite" --shell /sbin/nologin frr
RUN usermod -a -G frrvty frr

COPY docker-start.sh /app/lib/frr/docker-start.sh
RUN chmod +x /app/lib/frr/docker-start.sh
CMD ["/bin/bash","/app/lib/frr/docker-start.sh"]