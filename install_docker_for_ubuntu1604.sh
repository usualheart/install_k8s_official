# 用作给ubuntu 16.04 x86_64的机器安装docker的脚本
# 参考链接：https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
# 更新apt包索引 安装HTTPS支持的包
sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo apt-key fingerprint 0EBFCD88

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# 安装docker engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io

