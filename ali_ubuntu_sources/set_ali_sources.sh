# 备份旧源
mv /etc/apt/sources.list /etc/apt/sources.list.bak  #新建一个，然后将下面的内容copy进去
cp ./sources.list /etc/apt/
apt-get update
