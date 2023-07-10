git@github.com:geeker-smallwhite/scripts.git#########################################################################
# File Name:    cluster-add-user.sh
# Author:       geeker-smallwhite
# mail:         mandelgiegie@gmail.com
# Created Time: 一  7/10 23:33:40 2023
#########################################################################
#!/bin/bash
HOST=${1}
CONFIG=${2}
USERNAME=${3}

# check parameters is valid
if [ -z ${HOST} ]; then
    echo "HOST is Empty !"
    exit 1
fi

if [ -z ${CONFIG} ]; then
    CONFIG = "~/.kube/config"
    echo "config is ${CONFIG}"
fi

if [ -z ${USERNAME} ]; then
    echo "Username is Empty !"
    exit 1
fi

USERPATH="./${USERNAME}"
if [ -d ${USERPATH} ]; then
    echo "User already exists."
    exit 1
else
    mkdir -p "${USERPATH}"
fi


# generate key and csr for user

openssl genrsa -out ${USERPATH}/${USERNAME}.key 4096
openssl req -new -key ${USERPATH}/${USERNAME}.key -out ${USERPATH}/${USERNAME}.csr -subj "/CN=${USERNAME}"

# create and approve csr in k8s
B64=`cat ${USERPATH}/${USERNAME}.csr | base64 | tr -d '\n'`
cat <<EOF | kubectl --kubeconfig ${CONFIG} apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USERNAME}
spec:
  groups:
  - system:authenticated
  request: ${B64}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

kubectl --kubeconfig ${CONFIG} certificate approve ${USERNAME}
# create clusterrolebinding for user
kubectl --kubeconfig ${CONFIG} create clusterrolebinding cluster-admin-binding-${USERNAME} --clusterrole=cluster-admin --user=${USERNAME}

# create config file for user
KEY=`cat ${USERPATH}/${USERNAME}.key | base64 | tr -d '\n'`
CERT=`kubectl --kubeconfig ${CONFIG} get csr ${USERNAME} -o jsonpath='{.status.certificate}'`
echo "config create finished"
echo "config path is ${USERPATH}/config"
cat > "${USERPATH}/config" <<EOF
apiVersion: v1
clusters:
- cluster:
    server: ${HOST}
    insecure-skip-tls-verify: true
  name: k8s
contexts:
- context:
    cluster: k8s
    user: ${USERNAME}
  name: k8s
current-context: k8s
kind: Config
preferences: {}
users:
- name: ${USERNAME}
  user:
      client-certificate-data: ${CERT}
      client-key-data: ${KEY}
