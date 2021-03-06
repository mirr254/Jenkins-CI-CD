## AWS configure

. .env

#update time
sudo ntpdate ntp.ubuntu.com

## AWS Idenity And Access Management
## create user group
echo "Get user group ${AWS_USER_GROUP}..."
user_group="$(aws iam get-group --group-name $AWS_USER_GROUP | jq -r ".Group.GroupName")"
if [ "${user_group}" != ${AWS_USER_GROUP} ]; then
	echo "Create user group ${AWS_USER_GROUP}"
	aws iam create-group --group-name ${AWS_USER_GROUP}
	aws iam attach-group-policy --group-name ${AWS_USER_GROUP} --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
	aws iam attach-group-policy --group-name ${AWS_USER_GROUP} --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
	aws iam attach-group-policy --group-name ${AWS_USER_GROUP} --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess
	aws iam attach-group-policy --group-name ${AWS_USER_GROUP} --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
else
	echo "Using existing group..."
fi

## create user
echo "Get user ${AWS_USER}..."
user="$(aws iam get-user --user-name $AWS_USER | jq -r ".User.UserName")"
if [ "${user}" != "${AWS_USER}" ]; then
	echo "Create user ${AWS_USER}..."
	aws iam create-user --user-name ${AWS_USER}
else
	echo "Using existing user..."
fi

echo "Create AWS access key..."
create_access_key(){
	aws iam create-access-key --user-name ${AWS_USER} > kops-creds
	cat kops-creds 
}

## kops Access Keys
aws iam list-access-keys --user-name ${AWS_USER} > kops-creds
access_keys="$(cat kops-creds | jq -r '.AccessKeyMetadata')"
if [ "${access_keys}" == [] ]; then
	create_access_key
else
	# delete existing access keys
	for key in $(echo ${access_keys} | jq -c '.[]'); do
		access_key=$(echo ${key} | jq -r '.AccessKeyId')
		aws iam delete-access-key --user-name=${AWS_USER} --access-key-id=${access_key}
	done
	create_access_key
fi

delete_existing_key_pair(){
	echo "Delete exising key pair..."
	aws ec2 delete-key-pair --key-name ${AWS_KEY_NAME}
}

create_key_pair(){
	delete_existing_key_pair
	echo "Create new key pair..."
	aws ec2 create-key-pair --key-name ${AWS_KEY_NAME} | jq -r '.KeyMaterial' > kube-key.pem
	cat kube-key.pem
	chmod 400 kube-key.pem
	ssh-keygen -y -f kube-key.pem > kube-key.pub
	cat kube-key.pub
}

create_key_pair

echo "Get s3 bucket..."
## creating cluster state storage
buckets="$(aws s3api list-buckets | jq -r '.Buckets')"
found_bucket=false
for name in $( echo ${buckets} | jq -c '.[]'); do
        bucket_name=$(echo ${name} | jq -r '.Name')
        if [ ${bucket_name} == ${BUCKET_NAME} ]; then 
		found_bucket=true
	fi
done

if [ ${found_bucket} == false ]; then
	echo "Create s3 bucket..."
	echo $BUCKET_NAME
	aws s3api create-bucket --bucket $BUCKET_NAME 
	echo "KOP_STATE"
    echo $KOPS_STATE_STORE
else
	echo "Using existing s3 bucket..."
fi

#path to export configuration
echo "Export kubconfig"
kops export kubecfg --name $KOPS_CLUSTER_NAME --config=~$KUBECONFIG

echo "Creating cluster..."
# creating a cluster
kops create cluster --name $KOPS_CLUSTER_NAME --master-count 1 --master-size t2.micro --node-count 2 --node-size t2.micro --zones $ZONE --master-zones $ZONE --ssh-public-key kube-key.pub --yes

while true; do
  kops validate cluster --name $KOPS_CLUSTER_NAME | grep 'is ready' &> /dev/null
  if [ $? == 0 ]; then
     break
  fi
    sleep 30
done

kops get cluster
kubectl cluster-info


#kops validate cluster
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp $KUBECONFIG /var/lib/jenkins/.kube/
cd /var/lib/jenkins/.kube/
sudo chown jenkins:jenkins $KOPS_CLUSTER_NAME
sudo chmod 750 $KOPS_CLUSTER_NAME