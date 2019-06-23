FROM ncfgbase

# Install all the primary applications to be used/made available on the util
#   server.
RUN \
	apt-get update -y && \
	apt-get install -y \
		openssh-server \
		python-pip \
		golang-go \
		cmake \
		git \
		vim

RUN \
    sed -i -r 's/^[#\s]*(PasswordAuthentication).*$/\1 no/' /etc/ssh/sshd_config && \
    sed -i -r 's/^[#\s]*(PermitRootLogin).*$/\1 prohibit-password/' /etc/ssh/sshd_config

# Recommended by https://docs.docker.com/engine/examples/running_ssh_service/
#   but appears to not be needed, kept around in case it needs to be used
# RUN sed -i -r 's/(session\s*)required(\s*pam_loginuid.so)/\1optional\2/g' /etc/pam.d/sshd

# Install blobstore.
RUN curl -sfSL https://blob.aleemhaji.com/clientlib/installer.sh | bash

# Needed for the git repository manager.
RUN python -m pip install PyYAML

COPY ./authorized_keys /root/.ssh/authorized_keys
COPY ./app/mr /usr/sbin/mr
COPY ./docker-entrypoint.sh .

# Copy the repository manager to the container so that it can automatically
#   create the repository manager repo, and link the appropriate files if they
#   don't already exist properly.
COPY ./git /root/repository-manager

RUN \
    chmod 700 /root/.ssh && \
    chmod 500 /root/.ssh/authorized_keys && \
    chmod 755 /usr/sbin/mr && \
    chmod 755 ./docker-entrypoint.sh && \
    # Privilege separation directory needed by SSH.
    mkdir /var/run/sshd

EXPOSE 22

CMD ["./docker-entrypoint.sh"]
