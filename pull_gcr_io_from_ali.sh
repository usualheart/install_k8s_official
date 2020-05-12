# 通过命令行参数确定需要从gcr 拉取的镜像名 然后更改标签
#参数示例：kube-apiserver:v1.18.2 kube-scheduler:v1.18.2

# $*以一个单字符显示所有向脚本传递的参数
for imageName in $*; do
    #echo $imageName
    docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName
    docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName k8s.gcr.io/$imageName
    docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName
done
