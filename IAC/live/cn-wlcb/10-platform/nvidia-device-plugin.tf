# apply 时自动把已存在的 UK8S 自带 DS 收编进 state(免手动 terraform import)。
# 收编后由下方资源接管:device_plugin_enabled=false 时禁用到 0 个 Pod。
# 注:import 是一次性动作;DS 进 state 后此块留着无害(幂等)。
import {
  to = kubernetes_daemonset.nvidia_device_plugin
  id = "kube-system/nvidia-device-plugin-daemonset"
}
resource "kubernetes_daemonset" "nvidia_device_plugin" {
  metadata {
    name      = "nvidia-device-plugin-daemonset"
    namespace = "kube-system"
  }

  spec {
    selector {
      match_labels = {
        name = "nvidia-device-plugin-ds"
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_unavailable = 1
      }
    }

    template {
      metadata {
        labels = {
          name = "nvidia-device-plugin-ds"
        }
      }

      spec {
        # ---- 禁用开关 ----
        # enabled=false:叠加不存在的标签 → 该 DS 调度 0 个 Pod(等于禁用)
        # enabled=true :用空 selector → 按下方 affinity 调度到 GPU 节点
        node_selector = var.device_plugin_enabled ? {} : {
          "tf-device-plugin-disabled" = "true"
        }

        # 仅调度到带 accelerator 标签(且不为 none)的 GPU 节点(镜像 UK8S 原始 DS)
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "accelerator"
                  operator = "Exists"
                }
                match_expressions {
                  key      = "accelerator"
                  operator = "NotIn"
                  values   = ["none"]
                }
              }
            }
          }
        }

        # 容忍关键插件污点 + 所有 NoSchedule(镜像 UK8S 原始 DS)
        toleration {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        }
        toleration {
          operator = "Exists"
          effect   = "NoSchedule"
        }

        container {
          name              = "nvidia-device-plugin-ctr"
          image             = var.device_plugin_image
          image_pull_policy = "IfNotPresent"

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "device-plugin"
            mount_path = "/var/lib/kubelet/device-plugins"
          }
        }

        volume {
          name = "device-plugin"
          host_path {
            path = "/var/lib/kubelet/device-plugins"
          }
        }
      }
    }
  }
}
