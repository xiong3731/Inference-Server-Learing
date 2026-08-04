### 测试gpu
``` shell
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  restartPolicy: Never
  containers:
    - name: cuda-vectoradd
      image: nvcr.m.daocloud.io/nvidia/k8s/cuda-sample:vectoradd-cuda12.5.0
      resources:
        limits:
          nvidia.com/gpu: 1
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
EOF
```

查看grafana/prometheus
``` shell
kubectl -n monitoring port-forward svc/kps-grafana 3000:80  
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090
```