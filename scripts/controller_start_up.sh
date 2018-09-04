#!/bin/bash -e

log_info() {
  echo "INFO [$(date +%Y-%m-%d--%H:%M)] $1"
}

# download and bootstrap cfssl and cfssljson (pre-req for generating certs)

wget -q --https-only --timestamping \
  https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 \
  https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64

chmod +x cfssl_linux-amd64 cfssljson_linux-amd64
mv cfssl_linux-amd64 /usr/local/bin/cfssl
mv cfssljson_linux-amd64 /usr/local/bin/cfssljson

log_info "downloaded and installed cfssl and cfssljson"

# init variables

CFSSL_SERVER=$(curl -s -H "Metadata-Flavor: Google" \
 http://metadata.google.internal/computeMetadata/v1/instance/attributes/cfsslIP)

PUBLIC_IP=$(curl -s -H "Metadata-Flavor: Google" \
 http://metadata.google.internal/computeMetadata/v1/instance/attributes/publicIP)

ETCD_IPS=$(curl -s -H "Metadata-Flavor: Google" \
 http://metadata.google.internal/computeMetadata/v1/instance/attributes/controllerIPs)

INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
 http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)

ETCD_NAME=$(hostname -s)

# controller mapping is in the format of <hostname1>=https://<ip1>:PORT,<hostname2>=https://<ip2>:PORT. 
# :PORT needs to be replaced before use
CONTROLLER_MAPPING=$(curl -s -H "Metadata-Flavor: Google" \
 http://metadata.google.internal/computeMetadata/v1/instance/attributes/controllerMapping)

VPC_CIDR=$(curl -s -H "Metadata-Flavor: Google" \
 http://metadata.google.internal/computeMetadata/v1/instance/attributes/vpcCIDR)

HOSTNAME=$(hostname)

CLUSTER_CIDR=$(curl -s -H "Metadata-Flavor: Google" \
 http://metadata.google.internal/computeMetadata/v1/instance/attributes/clusterCIDR)

SERVICE_CLUSTER_CIDR=$(curl -s -H "Metadata-Flavor: Google" \
 http://metadata.google.internal/computeMetadata/v1/instance/attributes/serviceClusterCIDR)

# generate certs
gsutil cp gs://kube-certs/ca.pem .
gsutil cp gs://kube-certs/ca-key.pem .
gsutil cp gs://kube-certs/service-account.pem .
gsutil cp gs://kube-certs/service-account-key.pem .
gsutil cp gs://kube-certs/admin.kubeconfig .
gsutil cp gs://kube-certs/kube-scheduler.kubeconfig .
gsutil cp gs://kube-certs/kube-controller-manager.kubeconfig .

log_info "got certs from storage bucket"

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -remote="${CFSSL_SERVER}" -profile="kubernetes" \
 -hostname="${ETCD_IPS},${PUBLIC_IP},127.0.0.1,localhost,kubernetes.default" kubernetes-csr.json | cfssljson -bare kubernetes

log_info "generated cert for api server"

# create encryption key

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

log_info "generated encryption key"

# download and bootstrap etcd

wget -q --https-only --timestamping \
  "https://github.com/coreos/etcd/releases/download/v3.3.5/etcd-v3.3.5-linux-amd64.tar.gz"

tar -xvf etcd-v3.3.5-linux-amd64.tar.gz
mv etcd-v3.3.5-linux-amd64/etcd* /usr/local/bin/

log_info "downloaded etcd"

mkdir -p /etc/etcd /var/lib/etcd

cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster ${CONTROLLER_MAPPING//:PORT/:2380} \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

log_info "installed etcd as a services and restarting..."

systemctl daemon-reload
systemctl enable etcd
systemctl start etcd

# download and bootstrap api server, controller-manager, schedule and kubectl

wget -q --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubectl"

chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/

log_info "donwloaded apiserver, controller-manager, scheduler, kubectl"

# moving certs in place for api server, controller-manager, schedule and kubectl

mkdir -p /var/lib/kubernetes/

mv ca.pem ca-key.pem kubernetes-key.pem \
kubernetes.pem service-account-key.pem service-account.pem \
encryption-config.yaml kube-controller-manager.kubeconfig \
kube-scheduler.kubeconfig /var/lib/kubernetes/

log_info "moved certificates to /var/lib/kubernetes"

# service for api-server

ETCD_IP_ARRAY=(${ETCD_IPS//,/ })
ETCD_SERVERS=""

for i in "${ETCD_IP_ARRAY[@]}"
do
    if [ "${ETCD_SERVERS}" == "" ]; then
        ETCD_SERVERS="https://${i}:2379"
    else
        ETCD_SERVERS="${ETCD_SERVERS},https://${i}:2379"
    fi
done

log_info "ETCD_SERVERS = ${ETCD_SERVERS}"

cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=${#ETCD_SERVERS[@]} \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log_info \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=${ETCD_SERVERS} \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=${SERVICE_CLUSTER_CIDR} \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

log_info "loaded api server as a service"

# service for controller-manager

cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=${CLUSTER_CIDR} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=${SERVICE_CLUSTER_CIDR} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

log_info "loaded controller-manager as a service"

# service for scheduler

mkdir -p /etc/kubernetes/config

cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: componentconfig/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

log_info "loaded scheduler as a service"

# enable services

systemctl daemon-reload
systemctl enable kube-apiserver kube-controller-manager kube-scheduler
systemctl start kube-apiserver kube-controller-manager kube-scheduler

log_info "reloaded daemon and start apiserver, controller-manager, scheduler"
# setup nginx for health check

apt-get install -y nginx

cat > kubernetes.default.svc.cluster.local <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF

mv kubernetes.default.svc.cluster.local \
  /etc/nginx/sites-available/kubernetes.default.svc.cluster.local

ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/

systemctl restart nginx
systemctl enable nginx

log_info "installed nginx for health check"

# create role and user for kube api server to connect to kubelet

cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF

log_info "initialised role for admin user"