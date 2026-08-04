# Inference-Server-Learing

> 学习项目:用 Terraform 在 UCloud(乌兰察布)上搭建 LLM 推理平台,跑 SGLang + Qwen3-VL-4B-Instruct,覆盖「云资源 → K8s 集群 → 推理服务」全链路 IaC。

---

## 技术栈

| 用途 | 技术 |
| --- | --- |
| IaC | Terraform ≥ 1.5,UCloud provider ~1.39、kubernetes ~2.30、helm ~3.0 |
| 云资源 | UCloud:VPC、子网、安全组、NAT、EIP、云主机、UK8S 集群 |
| 集群 | UK8S(K8s 1.34.5),Ubuntu 24.04,containerd(CRI) |
| 推理 | SGLang 部署 Qwen3-VL-4B-Instruct,跨机 4 卡张量并行 |
| 模型存储 | UFile(S3 兼容),容器内 `aws s3 sync` 拉取 |
| 平台组件 | ingress、GPU Operator、Grafana/Prometheus、Dragonfly、NVIDIA device plugin |

---

## 三层架构

```text
00-infra(云资源)──outputs──▶ 10-platform(平台组件)──▶ 20-apps(推理服务)
  ucloud provider            helm/kubernetes            kubernetes/helm
```

每层独立 Terraform root + 独立 state,单向读上层 output。分层原因:

- **Provider 鸡生蛋**:kubernetes/helm provider 要连上集群才能初始化,而集群 apply 前不存在 → 混在一个 root 里首次创建必失败
- **爆炸半径不同**:VPC/集群很少动且危险,推理服务天天改镜像 tag。混在一个 state 里,改个 tag 都要 refresh 整个 VPC

---

## 目录结构

```text
IAC/
├── modules/                     # 共享云资源模块
│   ├── network/                 #   VPC / 子网 / 安全组
│   ├── nat/                     #   NAT 网关 + EIP
│   ├── uhost/                   #   独立云主机
│   └── uk8s/                    #   UK8S 集群 + CPU/GPU 节点池
└── live/
    └── cn-wlcb/                 # 乌兰察布地域
        ├── 00-infra/            # 第0层:云资源 —— ucloud provider
        ├── 10-platform/         # 第1层:平台组件 —— helm/kubernetes provider
        └── 20-apps/             # 第2层:推理服务 —— kubernetes/helm provider
```

---

## 各层详解

### 第 0 层 `00-infra` — 云资源

4 个模块装配,`main.tf` 就是清单:

| Module | 负责 | 关键 output |
| --- | --- | --- |
| `network` | VPC、子网、安全组(默认放行 TCP/UDP、拒 ICMP) | `vpc_id` / `subnet_id` / `security_group_id` |
| `nat` | NAT 网关 + EIP,让子网内主机访问外网 | `nat_public_ip` |
| `uhost` | 独立云主机(固定内网 IP + 独立 EIP) | `public_ip` / `private_ip` |
| `uk8s` | UK8S 集群 + CPU/GPU 节点池 | `cluster_id` / `external_api_server` |

镜像不写死:基础镜像用 `ucloud_images` 按 `^Ubuntu 24.04` 查询,UK8S 镜像用 `ucloud_uk8s_images` 按名字正则查询。

#### cloud-init 初始化

**云主机(UHost)**:UCloud 建机必填 root 密码,平时用私钥登录。通过 `user_data` 注入 `#cloud-config`,开机自动把 SSH 公钥写进 `root/authorized_keys`:

```yaml
#cloud-config
ssh_authorized_keys:
  - <公钥>
```

**UK8S 节点**(`init_script`,master/CPU/GPU 三种):

- **所有节点**:注入 SSH 公钥 + 重写 `/etc/containerd/config.toml` 为 `certs.d` 目录式配置,便于配镜像加速 / 私有仓库,重启 containerd
- **GPU 节点**额外:卸载镜像自带的 NVIDIA driver(`nvidia-uninstall -s` + `apt purge nvidia-container-toolkit nvidia-container-runtime libnvidia-container-*`),交给 10-platform 的 gpu-operator 统一安装管理 → **然后 reboot** 生效

#### 节点规格

写在 `00-infra/main.tf` 的 locals 里,可直接调:

- master ×3:4C8G,系统盘 40G
- CPU worker ×4:4C16G,系统盘 100G + 数据盘 200G
- GPU worker:异构池 map(rtx3090 池 32C64G × 2 卡,当前 `count=0`),加池只需在 map 加一项

### 第 1 层 `10-platform` — 平台组件

全部 helm release:

- **grafana** + **kube-prometheus-stack** — 监控,admin 账号密码走变量
- **gpu-operator** — GPU 节点统一装驱动;若 UK8S 镜像自带 driver 可设 `driver.enabled=false` 关掉
- **dragonfly** — P2P 镜像分发,集群节点拉镜像提速
- **nvidia-device-plugin** — DaemonSet,把 GPU 暴露成 `nvidia.com/gpu` 可调度资源
- **node-labels** — 给 UDisk 所在节点打 label

**镜像加速**:所有 helm values 的 registry 统一走 **DaoCloud 代理**(`docker.m.daocloud.io`、`quay.m.daocloud.io`),避开国内直连 docker.io 慢 / 被墙。

### 第 2 层 `20-apps` — 推理服务

核心是 `sglang.tf`,用原生 `kubernetes_*` 资源声明一套清单,四个关键设计:

1. **init_container 模型下载**:`model-downloader` 启动时 `aws s3 sync` 从 UFile(S3 兼容)拉模型到共享卷,写完 `.download_complete` 标记文件,重启不重复下载(幂等)
2. **StatefulSet `pod_management_policy = "Parallel"`**:两 Pod 并行创建。若用默认 `OrderedReady`,会等 sglang-0 ready 才建 sglang-1 → 跨机建链死锁
3. **Headless Service + `publish_not_ready_addresses = true`**:每个 Pod 有稳定 DNS(`sglang-0.sglang-headless...`),Pod 未 ready 也发布 DNS,否则跨机 TP 初始化互相找不到对方
4. **跨机张量并行**:`replicas=2` + `podAntiAffinity(hostname)` → 两个 Pod 各占一台 GPU 机;每 Pod 2 卡 + `--tp 4 --nnodes 2` → 跨机 4 卡张量并行

```text
sglang-0 (GPU机A, 2卡) ──┐
                         ├── headless DNS ──► --tp 4 --nnodes 2
sglang-1 (GPU机B, 2卡) ──┘

sglang-service → 只路由到 rank 0,对外提供 OpenAI 风格 API
```

其他细节:Secret 存 S3 凭证(`env_from.secret_ref`)、`shm_size` 等价 `docker --shm-size`、GPU 通过 `nvidia.com/gpu` limit 申请。

---

## 鉴权说明(UCloud 特有坑)

UCloud 的 `ucloud_uk8s_cluster` **不导出 kubeconfig / 证书**(只有 `api_server` / `external_api_server`)。所以 10/20 层用**本地 kubeconfig 文件**鉴权,不是从 output 自动拼证书。

kubeconfig 获取方式(任选一种)放到 `~/.kube/config` 或走 `kubeconfig_path` 变量:

- UCloud 控制台 → UK8S 集群详情页下载
- 登录 master 节点 `cat /root/.kube/config`

文件鉴权也顺带避开了 provider 鸡生蛋问题。

---

## 使用

按层顺序 apply,销毁逆序(先删服务,最后删云资源):

```bash
# 凭据用环境变量(勿写进仓库)
export TF_VAR_ucloud_public_key="..."
export TF_VAR_ucloud_private_key="..."

# ---- 第0层:云资源(约 10~20 分钟)----
cd live/cn-wlcb/00-infra
terraform init && terraform apply

# 集群建好后下载 kubeconfig,确认能连:
kubectl get nodes

# ---- 第1层:平台组件 ----
cd ../10-platform
cp terraform.tfvars.example terraform.tfvars   # 按需改
terraform init && terraform apply

# ---- 第2层:推理服务 ----
cd ../20-apps
terraform init && terraform apply
```

销毁:

```bash
cd live/cn-wlcb/20-apps && terraform destroy
cd ../10-platform       && terraform destroy
cd ../00-infra          && terraform destroy
```

### 新增地域

```bash
cp -r live/cn-wlcb live/cn-bj2
# 改各层 terraform.tfvars 里的 region / AZ / CIDR / 机型,modules 不动
```

---

## 安全

- `00-infra/terraform.tfvars` 含 **UCloud API 密钥对**(账号级权限)→ gitignore,只提交脱敏 `.tfvars.example`
- `kubeconfig`(集群管理员凭据)→ gitignore
- `*.tfstate`(含明文 root 密码 / K8s Secret)→ 删除 + gitignore
- 10-platform 的 grafana 密码按个人判断视为非敏感,随仓库提交

---

## 已知限制(UCloud provider)

| 限制 | 说明 |
| --- | --- |
| UK8S 不导出 kubeconfig | 本地文件鉴权,团队协作需自行分发 |
| UK8S 节点系统盘 | 部分机型无 `boot_disk_size`,用镜像默认 |
| UK8S 专用镜像(GPU 等) | 需用 `ucloud_uk8s_images` data source 按名字正则查询 |
| state 为本地文件 | 多人协作建议配 UCloud US3(S3 兼容)backend |

---

## 学习要点

- **Terraform 多 root 分层**:独立 state + 单向读 output,解决 provider 鸡生蛋、缩小爆炸半径
- **cloud-init**:`user_data` 注入 SSH 公钥;节点开机脚本做 containerd 配置、GPU 驱动卸载
- **SGLang 跨机张量并行**:StatefulSet Parallel 策略、headless DNS、podAntiAffinity 协同
- **镜像加速**:DaoCloud 代理 registry 统一替换
- **UCloud provider 特性**:UK8S 不导出 kubeconfig、镜像按正则查询等

## 进阶(可选)

- **远端 backend**:每层配 UCloud US3(S3 兼容)backend,`terraform_remote_state` 改读远端
- **GitOps**:20-apps 迭代频繁可改用 ArgoCD/Flux,00/10 层仍用 Terraform
