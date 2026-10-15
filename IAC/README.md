# IAC — UCloud 推理平台基础设施

用 Terraform 管理 UCloud 上的 LLM 推理平台,**按"层"划分**:云资源、集群平台组件、业务负载各自独立 state,互不干扰。

## 为什么分层(核心设计)

云资源(VPC / 集群)和 k8s 工作负载(helm / 清单)是**异步、异生命周期**的:

- **Provider 鸡生蛋**:`kubernetes` / `helm` provider 要连集群才能初始化,而集群在 apply 之前不存在。混在一个 root 里首次创建会失败。
- **爆炸半径不同**:VPC/集群很少动且危险;推理服务天天改镜像 tag。混在一个 state 里,改个 tag 都要 refresh 整个 VPC。

所以拆成三层 root,每层独立 `terraform apply`,通过 `terraform_remote_state` 单向读取上一层的 output。

## 目录结构

```
IAC/
├── modules/                     # 共享模块(云资源)
│   ├── network/  nat/  uhost/  uk8s/
└── live/
    └── cn-wlcb/                  # 乌兰察布地域
        ├── 00-infra/            # 第0层:云资源(VPC/NAT/主机/UK8S 集群)—— ucloud provider
        ├── 10-platform/         # 第1层:集群平台组件(ingress、gpu-operator、namespace)—— helm/kubernetes provider
        └── 20-apps/             # 第2层:业务负载(LLM 推理服务)—— kubernetes/helm provider
```

每层是独立 root,有自己的 `terraform.tfstate`。层间数据流:
`00-infra outputs` → `10-platform` 读 → `10-platform outputs` → `20-apps` 读。

## 鉴权说明(重要)

UCloud 的 `ucloud_uk8s_cluster` **不导出 kubeconfig / 证书**(只有 `api_server` / `external_api_server`)。
所以 10/20 层用**本地 kubeconfig 文件**鉴权,不是从 output 自动拼证书。

kubeconfig 获取方式(任选一种)后放到 `~/.kube/config` 或用 `kubeconfig_path` 指定:
- UCloud 控制台 → UK8S 集群详情页下载
- 登录 master 节点 `cat /root/.kube/config`

这种文件鉴权也顺带避开了 provider 鸡生蛋问题。

## 使用(按层顺序 apply)

```bash
# 凭据用环境变量
export TF_VAR_ucloud_public_key="..."
export TF_VAR_ucloud_private_key="..."

# ---- 第0层:云资源(建 VPC / 集群,约 10~20 分钟)----
cd live/cn-wlcb/00-infra
terraform init && terraform apply

# 集群建好后,下载 kubeconfig 到 ~/.kube/config,确认能连:
kubectl get nodes

# ---- 第1层:平台组件 ----
cd ../10-platform
cp terraform.tfvars.example terraform.tfvars   # 按需改
terraform init && terraform apply

# ---- 第2层:推理服务 ----
cd ../20-apps
terraform init && terraform apply
```

销毁按**逆序**(先删负载,最后删云资源):

```bash
cd live/cn-wlcb/20-apps    && terraform destroy
cd ../10-platform          && terraform destroy
cd ../00-infra             && terraform destroy
```

## 各层内容

| 层 | Provider | 管什么 |
| --- | --- | --- |
| `00-infra` | ucloud | VPC、子网、安全组、NAT、云主机、UK8S 集群 + CPU/GPU 节点池 |
| `10-platform` | helm / kubernetes | ingress-nginx、NVIDIA gpu-operator、`inference` 命名空间 |
| `20-apps` | kubernetes / helm | LLM 推理服务 Deployment + Service(申请 `nvidia.com/gpu`) |

> GPU 节点必须装 `gpu-operator`(在 10-platform),否则推理 Pod 调度不到显卡。
> 若 UK8S 节点镜像已自带 NVIDIA driver,把 `gpu-operator.tf` 里 `driver.enabled` 设为 `false`。

## 新增地域

```bash
cp -r live/cn-wlcb live/cn-bj2
# 改各层 terraform.tfvars 里的 region / AZ / CIDR / 机型,modules 不动
```

## 已知限制(UCloud provider ~> 1.47)

- **UK8S 集群不导出 kubeconfig**:见上文"鉴权说明",用本地文件鉴权。
- **镜像 ID 必须写死**:官方 provider 没有 UK8S 镜像数据源,`uk8s_image_id` 手填(镜像 ID 分分区,换区要改)。
- **CPU worker 系统盘大小不可调**:`ucloud_uk8s_node` 没有 `boot_disk_size`,用 API 默认值(master 和 GPU worker 块有)。
- **GPU 池落在 cluster 的 `worker` 块**:官方只有这里支持 `gpu`/`gpu_type`。两个代价:worker 块是 ForceNew,改 GPU 池规格或数量会重建整个集群;worker 块没有 `init_script`,GPU 节点拿不到开机脚本。

## 进阶(可选)

- **远端 backend**:目前 state 是本地文件。多人协作建议每层配 UCloud US3(S3 兼容)backend,`terraform_remote_state` 改读远端。
- **GitOps**:20-apps 若迭代频繁,可改用 ArgoCD/Flux 管理,00/10 层仍用 Terraform。
