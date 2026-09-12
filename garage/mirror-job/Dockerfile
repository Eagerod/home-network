FROM registry.internal.aleemhaji.com/debian:13.5

RUN \
    apt-get update && \
    apt-get install -y \
        curl && \
	apt-get clean

RUN \
    curl -fsS https://build.internal.aleemhaji.com/bin/mc/RELEASE.2023-09-29T16-41-22Z/mc -o /bin/mc && \
    chmod +x /bin/mc

ENTRYPOINT ["/bin/mc"]
