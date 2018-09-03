#!/bin/bash -e

# download and bootstrap cfssl and cfssljson

wget -q --https-only --timestamping \
  https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 \
  https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64

chmod +x cfssl_linux-amd64 cfssljson_linux-amd64
mv cfssl_linux-amd64 /usr/local/bin/cfssl
mv cfssljson_linux-amd64 /usr/local/bin/cfssljson

# download and bootstrap etcd

wget -q --https-only --timestamping \
  "https://github.com/coreos/etcd/releases/download/v3.3.5/etcd-v3.3.5-linux-amd64.tar.gz"

tar -xvf etcd-v3.3.5-linux-amd64.tar.gz
mv etcd-v3.3.5-linux-amd64/etcd* /usr/local/bin/

mkdir -p /etc/etcd /var/lib/etcd

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

CFSSL_SERVER=$(curl -s -H "Metadata-Flavor: Google" \
 http://metadata.google.internal/computeMetadata/v1/instance/attributes/cfsslIP)

PUBLIC_IP=$(curl -s -H "Metadata-Flavor: Google" \
 http://metadata.google.internal/computeMetadata/v1/instance/attributes/publicIP)

ETCD_IPS=$(curl -s -H "Metadata-Flavor: Google" \
 http://metadata.google.internal/computeMetadata/v1/instance/attributes/controllerIPs)

/usr/local/bin/cfssl gencert -remote="${CFSSL_SERVER}" -profile="kubernetes" \
 -hostname="${ETCD_IPS},${PUBLIC_IP},127.0.0.1,localhost,kubernetes.default" kubernetes-csr.json | /usr/local/bin/cfssljson -bare kubernetes

gsutil cp gs://kube-certs/ca.pem .

cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/

INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
 http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)

ETCD_NAME=$(hostname -s)

PUBLIC_IP=$(curl -s -H "Metadata-Flavor: Google" \
 http://metadata.google.internal/computeMetadata/v1/instance/attributes/publicIP)

# controller mapping is in the format of <hostname1>=https://<ip1>:PORT,<hostname2>=https://<ip2>:PORT. 
# :PORT needs to be replaced before use
CONTROLLER_MAPPING=$(curl -s -H "Metadata-Flavor: Google" \
 http://metadata.google.internal/computeMetadata/v1/instance/attributes/controllerMapping)

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

systemctl daemon-reload
systemctl enable etcd
systemctl start etcd