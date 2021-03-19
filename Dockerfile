#
# Copyright 2021 Hewlett Packard Enterprise Development LP
#

FROM arti.dev.cray.com/baseos-docker-master-local/alpine:3.12.1 AS crictl

RUN wget https://storage.googleapis.com/cri-containerd-release/cri-containerd-1.3.4.linux-amd64.tar.gz
RUN tar -xf cri-containerd-1.3.4.linux-amd64.tar.gz

FROM dtr.dev.cray.com/loftsman/docker-kubectl:latest

COPY --from=crictl usr/local/bin/crictl .
