FROM ncfgbase

RUN \
	apt-get update -y && \
	apt-get install -y mysql-server

RUN mkdir /var/run/mysqld
RUN chown mysql:mysql /var/run/mysqld

# Have to create an empty PID file for mysql to own so that it can take care of
#   writing to it when needed.
RUN touch /var/lib/mysqld.pid
RUN chown mysql:mysql /var/lib/mysqld.pid

USER mysql

CMD  ["/usr/sbin/mysqld", "--datadir=/var/lib/data", "--pid-file=/var/lib/mysqld.pid", "--bind-address=0.0.0.0"]

