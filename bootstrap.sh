apt-get update -y
apt-get install make

if [ ! -f bootstrap.make ]; then
    curl https://raw.githubusercontent.com/Eagerod/home-network/master/bootstrap.make -o bootstrap.make
fi

make -f bootstrap.make
