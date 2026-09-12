FROM registry.internal.aleemhaji.com/debian:13.5

RUN \
    apt-get update && \
    apt-get install -y \
        adb && \
	apt-get clean

RUN useradd -ms /bin/bash adb

USER adb
WORKDIR /home/adb
RUN mkdir .android
