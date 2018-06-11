FROM ubuntu:16.04

ENV TERM dummy
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get upgrade -y

RUN apt-get install -y curl

RUN echo 'deb http://www.ubnt.com/downloads/unifi/debian stable ubiquiti' | tee /etc/apt/sources.list.d/100-ubnt-unifi.list
RUN curl -sSL https://dl.ubnt.com/unifi/unifi-repo.gpg -o /etc/apt/trusted.gpg.d/unifi-repo.gpg

RUN apt-get update 
RUN apt-get install -y unifi
