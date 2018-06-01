docker build . -t pihole; winpty docker container run -p 80:80 -p 53:53/tcp -p 53:53/udp -it pihole
