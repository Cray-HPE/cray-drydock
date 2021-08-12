#
# Copyright 2021 Hewlett Packard Enterprise Development LP
#

FROM arti.dev.cray.com/baseos-docker-master-local/alpine:3.12.1 AS crictl

RUN wget https://storage.googleapis.com/cri-containerd-release/cri-containerd-1.3.4.linux-amd64.tar.gz
RUN tar -xf cri-containerd-1.3.4.linux-amd64.tar.gz

FROM arti.dev.cray.com/csm-docker-stable-local/docker-kubectl:0.2.1

COPY --from=crictl usr/local/bin/crictl .
