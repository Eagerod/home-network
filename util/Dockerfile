FROM ncfgbase

# Install all the primary applications to be used/made available on the util
#   server.
RUN \
    apt-get update -y && \
    apt-get install -y \
        dnsutils \
        iputils-ping \
        traceroute \
        openssh-server \
        python-pip \
        git \
        vim

RUN \
    sed -i -r 's/^[#\s]*(PasswordAuthentication).*$/\1 no/' /etc/ssh/sshd_config && \
    sed -i -r 's/^[#\s]*(PermitRootLogin).*$/\1 prohibit-password/' /etc/ssh/sshd_config

# Recommended by https://docs.docker.com/engine/examples/running_ssh_service/
#   but appears to not be needed, kept around in case it needs to be used
# RUN sed -i -r 's/(session\s*)required(\s*pam_loginuid.so)/\1optional\2/g' /etc/pam.d/sshd

# Install blobstore.
RUN \
    mkdir -p /usr/local/bin && \ 
    curl -sfSL https://blob.aleemhaji.com/client-bin/linux-amd64/latest-internal/blob > /usr/local/bin/blob && \
    chmod 755 /usr/local/bin/blob

COPY ./authorized_keys /root/.ssh/authorized_keys
COPY ./app/mr /usr/sbin/mr
COPY ./docker-entrypoint.sh .

RUN \
    chmod 700 /root/.ssh && \
    chmod 500 /root/.ssh/authorized_keys && \
    chmod 755 /usr/sbin/mr && \
    chmod 755 ./docker-entrypoint.sh && \
    # Privilege separation directory needed by SSH.
    mkdir /var/run/sshd

EXPOSE 22

CMD ["./docker-entrypoint.sh"]
