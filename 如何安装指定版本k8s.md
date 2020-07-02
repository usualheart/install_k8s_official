# 如何安装指定版本的k8s

## 安装指定版本k8s需要注意的三个地方：

- docker版本需要兼容

  下面就是docker过新而要安装的k8s比较旧导致的结果

  ```sh
  root@k8s0:~/install_k8s_official$ sudo ./init-master.sh 
  [init] Using Kubernetes version: v1.16.2
  [preflight] Running pre-flight checks
          [WARNING SystemVerification]: this Docker version is not on the list of validated versions: 19.03.11. Latest validated version: 18.09
  error execution phase preflight: [preflight] Some fatal errors occurred:
          [ERROR NumCPU]: the number of available CPUs 1 is less than the required 2
  [preflight] If you know what you are doing, you can make a check non-fatal with `--ignore-preflight-errors=...`
  To see the stack trace of this error execute with --v=5 or higher
  ```

- kubeadm、kubelet、kubectl需要兼容

- kubeadm init的时候可能需要额外指定一些参数。

  这个可以查阅k8s kubeadm的官方文档

## apt查询/安装指定版本的方法

通过网站搜索

https://packages.ubuntu.com/

apt查询

```sh
apt-cache madison <package name>
```

列出所有版本

```sh
apt-show-versions -a <<package name>>
```

**通过apt-get安装指定版本**

```
apt-get install <<package name>>=<<version>>
```

下边给出部署k8s v1.16和v1.14的示例。

# 部署k8s v1.16

## 安装与k8s v1.16兼容的docker版本：

  ```sh
  sudo apt-get install docker-ce=5:18.09.0~3-0~ubuntu-xenial docker-ce-cli=5:18.09.0~3-0~ubuntu-xenial containerd.io=1.2.0-1
  ```

## 安装指定版本的kubeadm kubectl kubelet

```sh
# 列出apt可以安装哪些版本
apt-cache madison kubeadm kubectl kubelet
# 安装指定版本 可以根据需要进行修改
sudo apt-get install kubeadm=1.16.10-00 kubelet=1.16.10-00 kubectl=1.16.10-00
```

## 初始化k8s集群master时需要指定kubernetes版本

使用kubeadm初始化一个master 可以通过修改kubernetes-version来指定kubernetes版本 也可以编写一个yaml配置文件来实现更复杂的自定义

```sh
sudo kubeadm init --apiserver-advertise-address 192.168.56.101 --kubernetes-version=v1.16.2 --image-repository=registry.aliyuncs.com/google_containers
```

> - --image-repository选项指定了自定义的镜像仓库来代替gcr.io 避免国内无法下载的问题
> - --kubernetes-version=v1.16.2设置了kubernetes的版本 需要注意这里的版本要与docker兼容

更多细节可以参考k8s官方文档对`kubeadm init`的说明

# 部署k8s v1.14

## k8s v1.14版本依赖

| 软件          | 版本                          |
| ------------- | ----------------------------- |
| docker-ce     | 17.03.0~ce-0~ubuntu-xenial    |
| docker-ce-cli | V17 docker只需要安装docker-ce |
| containerd.io | V17 docker只需要安装docker-ce |
| kubeadm       | v1.14.10                      |
| kubelet       | v1.14.10                      |
| kubectl       | v1.14.10                      |
| kubernetes    | v1.14.10                      |

参考v1.16中的安装语法安装即可。

## kubeadm初始化集群

```sh
kubeadm init --apiserver-advertise-address 172.16.4.100 --pod-network-cidr=192.168.100.0/24 --kubernetes-version=v1.14.10 --image-repository=registry.aliyuncs.com/google_containers
```

> 注意
>
> --pod-network-cidr=192.168.100.0/24 时安装v1.14特有的，如果不指定，之后安装pod网络插件会失败

