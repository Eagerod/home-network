FROM ubuntu:16.04

ENV TERM dummy
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get upgrade -y

RUN apt-get install -y mysql-server

RUN mkdir /var/run/mysqld
RUN chown mysql:mysql /var/run/mysqld

USER mysql

# CMD  ["/usr/sbin/mysqld", "--datadir=/var/lib/data", "--pid-file=/var/lib/mysqld.pid"]

