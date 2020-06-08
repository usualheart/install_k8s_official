# install_k8s_official
在国内环境下，借助阿里镜像源，按照官方的指导，使用脚本一步一步安装kubernetes。

Use the script to follow the official tutorial step by step to install kubernetes

# 准备工作
```sh
# 下载仓库代码到本地
git clone https://github.com/yu122/install_k8s_official.git
# 打开文件夹
cd install_k8s_official
# 配置阿里ubuntu源 可选
./ali_ubuntu_sources/set_ali_sources.sh
# 暂时关闭swap (利用 vi /etc/fstab 将swap一行注释掉并重启即可永久关闭)
sudo swapoff -a 
```

# 安装配置docker

- **[install_docker_for_ubuntu1604.sh](https://github.com/yu122/install_k8s_official/blob/master/install_docker_for_ubuntu1604.sh)**

  按照Docker官方指导，为ubuntu安装docker
## 与kubernetesv1.16兼容的docker版本：
  ```sh
  sudo apt-get install docker-ce=5:18.09.0~3-0~ubuntu-xenial docker-ce-cli=5:18.09.0~3-0~ubuntu-xenial containerd.io=1.2.0-1
  ```
  
##  注意安装比较旧的k8s时 需要注意docker的兼容性
下面就是docker过新而要安装的k8s比较旧导致的结果
```sh
yyb@k8s0:~/install_k8s_official$ sudo ./init-master.sh 
[init] Using Kubernetes version: v1.16.2
[preflight] Running pre-flight checks
        [WARNING SystemVerification]: this Docker version is not on the list of validated versions: 19.03.11. Latest validated version: 18.09
error execution phase preflight: [preflight] Some fatal errors occurred:
        [ERROR NumCPU]: the number of available CPUs 1 is less than the required 2
[preflight] If you know what you are doing, you can make a check non-fatal with `--ignore-preflight-errors=...`
To see the stack trace of this error execute with --v=5 or higher
```
  

## 配置docker

> 注意：docker安装完成后需要配置cgroup驱动为systemd来增强稳定性 具体说明参考：
https://kubernetes.io/zh/docs/setup/production-environment/container-runtimes/
```sh
# Set up the Docker daemon
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
```
```sh
mkdir -p /etc/systemd/system/docker.service.d
```
```sh
# Restart Docker
systemctl daemon-reload
systemctl restart docker
```

# 安装kubeadm kubelet kubectl

- **[kubeadm_install.sh](https://github.com/yu122/install_k8s_official/blob/master/kubeadm_install.sh)**
  
   按照k8s官方指导，安装kubeadm、kubelet、kubectl


- **[kubeadm_install_from_ali.sh](https://github.com/yu122/install_k8s_official/blob/master/kubeadm_install_from_ali.sh)**

  按照阿里官方指导，设置kubernetes阿里源，同时安装kubeadm、kubelet、kubectl。
## 安装指定版本的kubeadm kubectl kubelet
```sh
# 列出apt可以安装哪些版本
apt-cache madison kubeadm kubectl kubelet
# 安装指定版本 可以根据需要进行修改
sudo apt-get install kubeadm=1.16.10-00 kubelet=1.16.10-00 kubectl=1.16.10-00
```



# 初始化k8s集群master
使用kubeadm初始化一个master 可以通过修改kubernetes-version来指定kubernetes版本 也可以编写一个yaml配置文件来实现更复杂的自定义
```sh
sudo kubeadm init --apiserver-advertise-address 192.168.56.101 --kubernetes-version=v1.16.2 --image-repository=registry.aliyuncs.com/google_containers

```
> - --image-repository选项指定了自定义的镜像仓库来代替gcr.io 避免国内无法下载的问题
> - --kubernetes-version=v1.16.2设置了kubernetes的版本 需要注意这里的版本要与docker兼容

更多细节可以参考k8s官方文档对`kubeadm init`的说明
## 一些配置
在主节点执行：
```sh
# To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
# 安装pod网络插件
这里安装calico插件
```sh
kubectl apply -f https://docs.projectcalico.org/v3.14/manifests/calico.yaml
```
在这一步容易出现拉取calico镜像失败的问题，手动拉取：
```sh
docker pull calico/cni:v3.14.1
```
# 启用主节点调度
打开后pod会调度在主节点运行，这部执行完成后相当于拥有了一个单节点kubernetes
```
kubectl taint nodes --all node-role.kubernetes.io/master-
```
# 加入节点
待更新。


# 辅助工具
> 如果kubeadm init中已经指定了`--image-repository=registry.aliyuncs.com/google_containers`就不需要再手动拉取k8s镜像以及手动打标签了
- **[pull_k8s_gcr_io_from_ali.sh](https://github.com/yu122/install_k8s_official/blob/master/pull_k8s_gcr_io_from_ali.sh)**

  用于从阿里gcr.io镜像拉取安装k8s所必须的gcr.io镜像，并更改镜像标签为gcr.io。结果就好像是直接从gcr.io拉取到了安装kubernetes所需的镜像。

- **[pull_gcr_io_from_ali.sh](https://github.com/yu122/install_k8s_official/blob/master/pull_gcr_io_from_ali.sh)**

  从阿里gcr.io镜像拉取指定gcr.io镜像并更改镜像标签为gcr.io。镜像名通过脚本参数指定。

- **[calico_image.txt](https://github.com/yu122/install_k8s_official/blob/master/calico_image.txt)**

  pod网络插件calico所依赖的镜像，在安装kubernetes的时候需要配置pod网络插件，如果这个环节失败，可以通过手动拉取calico镜像的方式解决。

- **[ali_ubuntu_sources](https://github.com/yu122/install_k8s_official/tree/master/ali_ubuntu_sources)**

  配置ubuntu16.04阿里源。