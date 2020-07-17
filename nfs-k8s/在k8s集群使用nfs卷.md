# 如何在kubernetes集群中使用nfs存储卷——通过自建nfs服务器

对于运行在云服务商中的k8s集群（比如GKE等），有比较完善的存储卷支持。而自建的k8s集群，这方面往往比较麻烦。经过调查，发现在自建k8s集群中使用nfs卷是一个比较简单可行的方案。nfs服务器可以独立于k8s集群，便于集中管理集群中的卷和文件。

本文内容包括：

- 安装配置nfs服务器
- 使用nfs客户端连接nfs共享文件夹
- 在k8s集群中通过手动方式创建nfs卷

> 本文实验环境为ubuntu/Debian，对于centos等系统，只在于nfs的安装和配置略有不同。

## 安装配置nfs服务器

>  参考教程：https://vitux.com/install-nfs-server-and-client-on-ubuntu/

### 步骤1: 安装nfs-kernel-server

```sh
sudo apt-get update
sudo apt install nfs-kernel-server
```

### 步骤2: 创建导出目录

导出目录是用于与nfs客户端共享的目录，这个目录可以是linux上的任意目录。这里我们使用一个创建的新目录。

```sh
sudo mkdir -p /mnt/sharedfolder
#后边两步非常关键，如果没有这两步，可能导致其它客户端连接后出现访问禁止的错误
sudo chown nobody:nogroup /mnt/sharedfolder
sudo chmod 777 /mnt/sharedfolder
```

### 步骤3: 通过nfs输出文件为客户端分配服务器访问权限

编辑`/etc/exports`文件

```sh
sudo vi /etc/exports
```

#### 在文件中追加配置，可以分配不同类型的访问权限：

- 分配给单个客户端访问权限的配置格式：

```
/mnt/sharedfolder clientIP(rw,sync,no_subtree_check)
```

- 分配给多个客户端访问权限的配置格式：

```
/mnt/sharedfolder client1IP(rw,sync,no_subtree_check)
/mnt/sharedfolder client2IP(rw,sync,no_subtree_check)
```

- 通过指定一个完整的客户端子集来分配多个客户端访问权限的配置格式：

```
/mnt/sharedfolder subnetIP/24(rw,sync,no_subtree_check)
```

示例：

这是分配给192.168.0.101客户端读写权限的示例配置

```
/mnt/sharedfolder 192.168.0.101(rw,sync,no_subtree_check)
```

### 步骤4: 输出共享目录

执行命令，输出共享目录：

```sh
sudo exportfs -a
```

重启nfs-kernel-server服务，使所有配置生效

```sh
sudo systemctl restart nfs-kernel-server
```

## 使用nfs客户端连接nfs共享文件夹

可以使用win10的资源管理器连接nfs服务器进行测试，也可以使用linux连接测试。

这里使用局域网另一台ubuntu挂载nfs共享目录进行测试：

### 步骤1: 安装nfs-common

nfs-common包含nfs客户端所需的软件

```sh
sudo apt-get update
sudo apt-get install nfs-common
```

### 步骤2: 创建一个用于nfs共享目录的挂载点

```
sudo mkdir -p /mnt/sharedfolder_client
```

### 步骤3: 挂在共享目录到客户端

挂载命令格式：

`sudo mount serverIP:/exportFolder_server /mnt/mountfolder_client`

根据之前的配置，挂载命令如下：

```sh
sudo mount 192.168.100.5:/mnt/sharedfolder /mnt/sharedfolder_client
```

> 具体配置时，需要根据实际nfs server ip地址填写

### 步骤4: 测试连接

可以往共享目录复制文件，在其他机器上可以看到这个文件。

## 在k8s集群中通过手动方式创建nfs卷

> 参考教程：https://medium.com/@myte/kubernetes-nfs-and-dynamic-nfs-provisioning-97e2afb8b4a9

### 创建基于nfs的pv

`nfs.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
  labels:
    name: mynfs # name can be anything
spec:
  storageClassName: manual # same storage class as pvc
  capacity:
    storage: 200Mi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 192.168.1.7 # ip addres of nfs server
    path: "/srv/nfs/mydata2" # path to directory
```

部署nfs.yaml:

```sh
$ kubectl apply -f nfs.yaml
$ kubectl get pv,pvc
persistentvolume/nfs-pv   100Mi      RWX            Retain           Available
```

### 创建pvc

创建持久卷声明文件，并部署，需要注意accessModes必须要与之前创建的pv中一致

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany #  must be the same as PersistentVolume
  resources:
    requests:
      storage: 50Mi
```

部署

```sh
$ kubectl apply -f nfs_pvc.yaml
$ kubectl get pvc,pv
persistentvolumeclaim/nfs-pvc   Bound    nfs-pv   100Mi      RWX
```

### 创建pod

创建一个简单的使用这个pvc的nginx部署，`nfs-pod.yaml`：

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: nginx
  name: nfs-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      volumes:
      - name: nfs-test
        persistentVolumeClaim:
          claimName: nfs-pvc # same name of pvc that was created
      containers:
      - image: nginx
        name: nginx
        volumeMounts:
        - name: nfs-test # name of volume should match claimName volume
          mountPath: /usr/share/nginx/html # mount inside of contianer
```

部署Nginx:

```sh
$ kubectl apply -f nfs_pod.yaml 
$ kubectl get po
nfs-nginx-6cb55d48f7-q2bvd   1/1     Running
```

### 常见问题：创建pod失败--原因缺少nfs驱动

在k8s中创建使用nfs卷的pod出现错误：

原因：在节点上没有安装挂载nfs客户端所需要的软件包

```sh
root@k8s0:~# kubectl describe pod/nfs-nginx-766d4bf45f-n7dlt
Name:         nfs-nginx-766d4bf45f-n7dlt
Namespace:    default
Priority:     0
Node:         k8s2/172.16.2.102
Start Time:   Fri, 10 Jul 2020 18:04:58 +0800
Labels:       app=nginx
              pod-template-hash=766d4bf45f
Annotations:  cni.projectcalico.org/podIP: 192.168.109.86/32
Status:       Running
IP:           192.168.109.86
IPs:
  IP:           192.168.109.86
Controlled By:  ReplicaSet/nfs-nginx-766d4bf45f
Containers:
  nginx:
    Container ID:   docker://88299398d40ead29e991e57c6bad5d0e6d0396c21c2e69b0d2afb4ab7cce6044
    Image:          nginx
    Image ID:       docker-pullable://nginx@sha256:21f32f6c08406306d822a0e6e8b7dc81f53f336570e852e25fbe1e3e3d0d0133
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Fri, 10 Jul 2020 18:17:00 +0800
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /usr/share/nginx/html from nfs-test (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-mhtqt (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             True 
  ContainersReady   True 
  PodScheduled      True 
Volumes:
  nfs-test:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  nfs-pvc
    ReadOnly:   false
  default-token-mhtqt:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-mhtqt
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type     Reason       Age        From               Message
  ----     ------       ----       ----               -------
  Normal   Scheduled    <unknown>  default-scheduler  Successfully assigned default/nfs-nginx-766d4bf45f-n7dlt to k8s2
  Warning  FailedMount  21m        kubelet, k8s2      MountVolume.SetUp failed for volume "nfs-pv" : mount failed: exit status 32
Mounting command: systemd-run
Mounting arguments: --description=Kubernetes transient mount for /var/lib/kubelet/pods/9c0b53d9-581c-4fc4-a286-7c4a8d470e74/volumes/kubernetes.io~nfs/nfs-pv --scope -- mount -t nfs 172.16.100.105:/mnt/sharedfolder /var/lib/kubelet/pods/9c0b53d9-581c-4fc4-a286-7c4a8d470e74/volumes/kubernetes.io~nfs/nfs-pv
Output: Running scope as unit run-r3892d691a70441eb975bc53bb7aeca72.scope.
mount: wrong fs type, bad option, bad superblock on 172.16.100.105:/mnt/sharedfolder,
       missing codepage or helper program, or other error
       (for several filesystems (e.g. nfs, cifs) you might
       need a /sbin/mount.<type> helper program)

       In some cases useful info is found in syslog - try
       dmesg | tail or so.
  Warning  FailedMount  21m  kubelet, k8s2  MountVolume.SetUp failed for volume "nfs-pv" : mount failed: exit status 32
Mounting command: systemd-run
Mounting arguments: --description=Kubernetes transient mount for /var/lib/kubelet/pods/9c0b53d9-581c-4fc4-a286-7c4a8d470e74/volumes/kubernetes.io~nfs/nfs-pv --scope -- mount -t nfs 172.16.100.105:/mnt/sharedfolder /var/lib/kubelet/pods/9c0b53d9-581c-4fc4-a286-7c4a8d470e74/volumes/kubernetes.io~nfs/nfs-pv
Output: Running scope as unit run-r8774f015f759436d843d408eb6c941ec.scope.
```

解决办法:

ubuntu/debian在k8s节点上执行,安装nfs客户端支持

```sh
sudo apt-get install nfs-common
```

安装完成后过一段时间，可以发现pod能够正常运行

### 测试k8s正确使用了nfs卷

在nginx pod中创建一个测试网页，文件名index.html：

```sh
$ kubectl exec -it nfs-nginx-6cb55d48f7-q2bvd bash
#填入index.html内容用于测试
$ sudo vi /usr/share/nginx/html/index.html
this should hopefully work
```

可以验证nfs服务器上现在已经有了同样的文件，并且验证nginx可以读取这个文件：

```sh
$ ls /srv/nfs/mydata$
$ cat /srv/nfs/mydata/index.html
this should hopefully work
# 将nginx pod通过nodeport暴露为服务，以使可通过浏览器访问
$ kubectl expose deploy nfs-nginx --port 80 --type NodePort
$ kubectl get svc
$ nfs-nginx    NodePort    10.102.226.40   <none>        80:32669/TCP
```

打开浏览器，输入 <相应节点的ip>:<端口> 

本例是：192.168.99.157:32669

![image-20200710184912975](在k8s集群使用nfs卷.assets/image-20200710184912975.png)

删除所有部署，可以验证测试文件仍然存在我们的目录中：

```sh
$ kubectl delete deploy nfs-nginx
$ kubectl delete pvc nf-pvc
--> kubectl delete svc nfs-nginx
$ ls /srv/nfs/mydata/
index.html
```

## 在k8s集群实现动态nfs卷供应

> 参考教程： [https://medium.com/@myte/kubernetes-nfs-and-dynamic-nfs-provisioning-97e2afb8b4a9](https://medium.com/@myte/kubernetes-nfs-and-dynamic-nfs-provisioning-97e2afb8b4a9)
> k8s nfs 客户端仓库： [https://github.com/kubernetes-incubator/external-storage/tree/master/nfs-client](https://github.com/kubernetes-incubator/external-storage/tree/master/nfs-client)

### 步骤1: 在nfs服务器上配置新的导出目录

导出目录是用于与nfs客户端共享的目录，这个目录可以是linux上的任意目录。这里我们使用一个创建的新目录。

```sh
sudo mkdir -p /srv/nfs/mydata2
#后边两步非常关键，如果没有这两步，可能导致其它客户端连接后出现访问禁止的错误
sudo chown nobody:nogroup /srv/nfs/mydata2
sudo chmod 777 /srv/nfs/mydata2
```

配置nfs-server

```sh
sudo vi /etc/exports
	-->添加对目录的路径 可以参考之前的配置
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
```

### 步骤2：创建服务账户

https://gist.github.com/Ccaplat/99f316f4435b1ec5fe3d1af01dfefd56/raw/c5ce0cf39318c4abc49fe342f5141f29643400f0/rbac.yaml

```yaml
kind: ServiceAccount
apiVersion: v1
metadata:
  name: nfs-pod-provisioner-sa
---
kind: ClusterRole # Role of kubernetes
apiVersion: rbac.authorization.k8s.io/v1 # auth API
metadata:
  name: nfs-provisioner-clusterRole
rules:
  - apiGroups: [""] # rules on persistentvolumes
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-provisioner-rolebinding
subjects:
  - kind: ServiceAccount
    name: nfs-pod-provisioner-sa # defined on top of file
    namespace: default
roleRef: # binding cluster role to service account
  kind: ClusterRole
  name: nfs-provisioner-clusterRole # name defined in clusterRole
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-pod-provisioner-otherRoles
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-pod-provisioner-otherRoles
subjects:
  - kind: ServiceAccount
    name: nfs-pod-provisioner-sa # same as top of the file
    # replace with namespace where provisioner is deployed
    namespace: default
roleRef:
  kind: Role
  name: nfs-pod-provisioner-otherRoles
  apiGroup: rbac.authorization.k8s.io
```

Deploying the service account:

```
$ kubectl apply -f rbac.yaml
serviceaccount/nfs-pod-provisioner created
clusterrole.rbac.authorization.k8s.io/nfs-provisioner-clusterRole created
clusterrolebinding.rbac.authorization.k8s.io/nfs-provisioner-rolebinding created
role.rbac.authorization.k8s.io/nfs-pod-provisioner-otherRoles created
rolebinding.rbac.authorization.k8s.io/nfs-pod-provisioner-otherRoles created$ kubectl get clusterrole,role 
```

### 步骤3：创建一个storage classs

https://gist.github.com/Ccaplat/1578c81282339fdccc749458f95e7c9c/raw/96c8bc962eb79e110b490fcbc38b7a6e4ecc2534/nfs_class.yaml

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-storageclass # IMPORTANT pvc needs to mention this name
provisioner: nfs-test # name can be anything
parameters:
  archiveOnDelete: "false"
```

```
$ kubectl create -f nfs_class.yaml
$ bubectl get storageclass
NAME                 PROVISIONER                AGE
nfs-storageclass     nfs-pod
```

### 步骤4：以pod方式部署NFS client provisioner

 [NFS client provisioner github](https://github.com/kubernetes-incubator/external-storage/tree/master/nfs-client)

yaml文件：https://gist.github.com/Ccaplat/fc69461b7f47eb6791e050da2f151f26/raw/81bbd0c99beb0255ca32a24ed77f101605a9d786/nfs_pod_provision.yaml

> 注意 这个配置文件中有些选项需要根据实际情况进行修改
>
> 链接中的yaml文件缺少spec.selector字段

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: nfs-pod-provisioner
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-pod-provisioner
  template:
    metadata:
      labels:
        app: nfs-pod-provisioner
    spec:
      serviceAccountName: nfs-pod-provisioner-sa # name of service account created in rbac.yaml
      containers:
        - name: nfs-pod-provisioner
          image: quay.io/external_storage/nfs-client-provisioner:latest
          volumeMounts:
            - name: nfs-provisioner-v
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME # do not change
              value: nfs-test # SAME AS PROVISONER NAME VALUE IN STORAGECLASS
            - name: NFS_SERVER # do not change
              value: 192.168.1.7 # Ip of the NFS SERVER
            - name: NFS_PATH # do not change
              value: /srv/nfs/mydata2 # path to nfs directory setup
      volumes:
       - name: nfs-provisioner-v # same as volumemouts name
         nfs:
           server: 192.168.1.7
           path: /srv/nfs/mydata2
```

Deploying the NFS client pod:

```
$ kubectl apply -f nfs_pod_provision.yaml
pod/nfs-pod-provisioner-66ffbbbbf-sg4kh   1/1     Running   0          7s
$ kubectl describe po nfs-pod-provisioner-66ffbbbbf-sg4kh
 nfs-provisioner-v:
    Type:      NFS (an NFS mount that lasts the lifetime of a pod)
    Server:    192.168.1.7
    Path:      /srv/nfs/mydata2
     Mounts:
      /persistentvolumes from nfs-provisioner-v (rw)
```

The NFS client has been attached to the NFS server and mounted to the persistence volume with Read and Write permission.

### 步骤5：测试

请求并部署一个pvc：

https://gist.github.com/Ccaplat/7fbce589a37c8083816b1b7f7266d3ac/raw/69b98ccaccaacde51d6207cdf11f06119d2940d9/nfs_pvc_dynamic.yaml

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc-test
spec:
  storageClassName: nfs-storageclass # SAME NAME AS THE STORAGECLASS
  accessModes:
    - ReadWriteMany #  must be the same as PersistentVolume
  resources:
    requests:
      storage: 50Mi
```

```
$ kubectl get pv,pvc
$ kubectl apply -f  nfs_pvc_dynamic.yaml
nfs-pvc-test   Bound    pvc-620ff5b1-b2df-11e9-a66a-080027db98ca   50Mi       RWX            nfs-storageclass   7s
$ ls /srv/nfs/mydata2/
default-nfs-pvc-test-pvc-620ff5b1-b2df-11e9-a66a-080027db98ca
```

可以看到在 mydata2/文件夹中创建了一个default-nfs-pvc-test… 文件夹

这个pvc所创建的文件都会在这个文件夹下。

#### 部署一个nginx来进行测试:

https://gist.github.com/Ccaplat/d6bca372a794215b1d526812ff6e5cff/raw/16d878a86f0546d772df862bb5c1f1ea77bcb5a0/nginx_nfs.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx
  name: nfs-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      volumes:
      - name: nfs-test #
        persistentVolumeClaim:
          claimName: nfs-pvc-test  # same name of pvc that was created
      containers:
      - image: nginx
        name: nginx
        volumeMounts:
        - name: nfs-test # name of volume should match claimName volume
          mountPath: mydata2 # mount inside of contianer
```

```
$ kubectl get po 
nfs-nginx-76c48f6466-fnkh9             1/1     Running   0
```

在pod中创建一个txt文件，并且验证它存在于nfs对应的文件夹中：

```
$ kubectl exec -it po nfs-nginx-76c48f6466-fnkh9 bash
$ cd mydata2/
$ root@nfs-nginx-76c48f6466-fnkh9:/mydata2# touch testfile.txt
$ exit$ ls /srv/nfs/mydata2/default-nfs-pvc-test-pvc-620ff5b1-b2df-11e9-a66a-080027db98ca/
testfile.txt
```

Voila! The file was replicated and the NFS client is working correctly