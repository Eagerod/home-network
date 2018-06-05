FROM ubuntu:16.04

ENV TERM dummy
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get upgrade -y

RUN apt-get install -y easy-rsa

RUN make-cadir /var/lib/openvpn-ca

ARG KEY_COUNTRY 
ARG KEY_PROVINCE 
ARG KEY_CITY 
ARG KEY_ORG 
ARG KEY_EMAIL 
ARG KEY_OU 
ARG KEY_NAME 
ARG KEY_CN

