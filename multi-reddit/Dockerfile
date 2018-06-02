FROM ubuntu:16.04

ENV TERM dummy
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get upgrade -y

RUN apt-get install -y openssh-server

# Privilege separation directory needed by SSH.
RUN mkdir /var/run/sshd

RUN sed -i -r 's/^[#\s]*(PasswordAuthentication).*$/\1 no/' /etc/ssh/sshd_config
RUN sed -i -r 's/^[#\s]*(PermitRootLogin).*$/\1 prohibit-password/' /etc/ssh/sshd_config

# Recommended by https://docs.docker.com/engine/examples/running_ssh_service/
#   but appears to not be needed, kept around in case it needs to be used
# RUN sed -i -r 's/(session\s*)required(\s*pam_loginuid.so)/\1optional\2/g' /etc/pam.d/sshd

RUN apt-get install -y \
	curl \
	unzip \
	golang-go \
	cmake \
	git
RUN curl https://aleem.haji.ca/blob/clientlib/installer.sh | bash

COPY ./authorized_keys /root/.ssh/authorized_keys
RUN chmod 700 /root/.ssh
RUN chmod 500 /root/.ssh/authorized_keys

COPY ./app/* /usr/sbin/

ARG DFAULT_BLOBSTORE_WRITE_ACL
ARG DEFAULT_BLOBSTORE_READ_ACL
ARG MULTI_REDDIT_SUBS_LOCATION
ARG MULTI_REDDIT_SAVED_LOCATION

RUN sed -i -r "s/(DEFAULT_BLOBSTORE_READ_ACL=).*/\1$DEFAULT_BLOBSTORE_READ_ACL/g" /usr/sbin/mr
RUN sed -i -r "s/(DEFAULT_BLOBSTORE_WRITE_ACL=).*/\1$DEFAULT_BLOBSTORE_WRITE_ACL/g" /usr/sbin/mr
RUN sed -i -r "s#(MULTI_REDDIT_SUBS_LOCATION=).*#\1$MULTI_REDDIT_SUBS_LOCATION#g" /usr/sbin/mr
RUN sed -i -r "s#(MULTI_REDDIT_SAVED_LOCATION=).*#\1$MULTI_REDDIT_SAVED_LOCATION#g" /usr/sbin/mr

EXPOSE 22

# CMD ["/usr/sbin/sshd", "-D"]

