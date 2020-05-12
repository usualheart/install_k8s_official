# install_k8s_official
在国内环境下，借助阿里镜像源，按照官方的指导，使用脚本一步一步安装kubernetes。

Use the script to follow the official tutorial step by step to install kubernetes

## 脚本介绍：

- **[install_docker_for_ubuntu1604.sh](https://github.com/yu122/install_k8s_official/blob/master/install_docker_for_ubuntu1604.sh)**

  按照Docker官方指导，为ubuntu安装docker

- **[kubeadm_install.sh](https://github.com/yu122/install_k8s_official/blob/master/kubeadm_install.sh)**

  按照k8s官方指导，安装kubeadm、kubelet、kubectl

- **[kubeadm_install_from_ali.sh](https://github.com/yu122/install_k8s_official/blob/master/kubeadm_install_from_ali.sh)**

  按照阿里官方指导，设置kubernetes阿里源，同时安装kubeadm、kubelet、kubectl。

- **[pull_k8s_gcr_io_from_ali.sh](https://github.com/yu122/install_k8s_official/blob/master/pull_k8s_gcr_io_from_ali.sh)**

  从阿里gcr.io镜像拉取安装k8s所必须的gcr.io镜像，并更改镜像标签为gcr.io。结果就好像是直接从gcr.io拉取到了安装kubernetes所需的镜像。

- **[pull_gcr_io_from_ali.sh](https://github.com/yu122/install_k8s_official/blob/master/pull_gcr_io_from_ali.sh)**

  从阿里gcr.io镜像拉取指定gcr.io镜像并更改镜像标签为gcr.io。镜像名通过脚本参数指定。

- **[calico_image.txt](https://github.com/yu122/install_k8s_official/blob/master/calico_image.txt)**

  pod网络插件calico所依赖的镜像，在安装kubernetes的时候需要配置pod网络插件，如果这个环节失败，可以通过手动拉取calico镜像的方式解决。

- **[ali_ubuntu_sources](https://github.com/yu122/install_k8s_official/tree/master/ali_ubuntu_sources)**

  按照阿里源官方指导，用于配置ubuntu16.04为阿里源的脚本。

# k8s集群脚本执行顺序

```sh
# 下载仓库到本地
git clone https://github.com/yu122/install_k8s_official.git
# 打开文件夹
cd install_k8s_official
# 配置阿里ubuntu源
./ali_ubuntu_sources/set_ali_sources.sh
# 安装docker
./install_docker_for_ubuntu1604.sh
### 暂时关闭swap
sudo swapoff -a 
# 设置kubernetes阿里源，同时安装kubeadm、kubelet、kubectl。
./kubeadm_install_from_ali.sh
# 通过阿里代理下载kubernetes所需要的gcr.io镜像，并改标签为gcr.io
./pull_gcr_io_from_ali.sh
# 使用kubeadm初始化一个master
....待更新
```
