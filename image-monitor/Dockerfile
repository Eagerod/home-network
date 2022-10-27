FROM registry.internal.aleemhaji.com/ubuntu:20.04

# Bare bones image-monitor required dependencies.
RUN \
    apt-get update -y && \
    apt-get install -y \
        curl \
		jq && \
    apt-get clean

# For the image monitor.
RUN \
    apt-get update -y && \
    apt-get install -y \
        dnsutils && \
    apt-get clean
