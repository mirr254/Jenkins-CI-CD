#!/bin/bash

set -o errexit #set -e  #exit immediately if a command  exits with non-zero status
set -o xtrace #set -x #to trace what gets executed. Useful for debugging.

echo "Generate public key from pem file"
chmod 400 /home/ubuntu/kungu_admin.pem
ssh-keygen -y -f /home/ubuntu/kungu_admin.pem > /home/ubuntu/.ssh/id_rsa.pub

echo "Creating cluster..."
kops create cluster --dns-zone shammir.tk --zones us-west-1a --master-size t2.micro --node-size t2.micro --name $CLUSTER_NAME --ssh-public-key /home/ubuntu/.ssh/id_rsa.pub --yes
echo "************************ validate cluster **************************"
while true; do
  kops validate cluster --name $CLUSTER_NAME | grep 'is ready' &> /dev/null
  if [ $? == 0 ]; then
    break
  fi
    sleep 30
done

echo "<<<<<<<<<<<<< get the cluster >>>>>>>>>>>>>"
kops get cluster
kubectl cluster-info
kubectl apply namespace ingress

echo "Add Dashboard"
kubectl create -f https://raw.githubusercontent.com/kubernetes/kops/master/addons/kubernetes-dashboard/v1.4.0.yaml

echo "Add ingress"
kubectl create namespace ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash
helm init
helm install stable/nginx-ingress --name my-nginx --set rbac.create=true

echo "Add jenkins user to docker group"
sudo usermod -a -G docker jenkins
sudo service jenkins restart

echo "Give Jenkins rights to run kubernetes"
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp ~/.kube/config /var/lib/jenkins/.kube/
cd /var/lib/jenkins/.kube/
sudo chown jenkins:jenkins config
sudo chmod 750 config