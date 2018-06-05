FROM ubuntu:16.04

ENV TERM dummy
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get upgrade -y

RUN apt-get install -y openvpn

ADD ./dh.pem ./dh.pem

