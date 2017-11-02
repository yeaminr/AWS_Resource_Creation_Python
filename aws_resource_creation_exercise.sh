#!/bin/bash

#Script Name: aws_resource_creation_exercise.sh
#Author: Yeamin Rajeev (yeamin.rajeev@gmail.com)
#Version: 1.0
#Description: This Bash script creates a number of AWS resources using the AWS CLI of an Amazon Linux AMI EC2 instance 
#Dependencies: Please check the requirements.txt file for details. 

######
###### The below block of code checks if the 1st argument $1 is a valid EC2 instance type name, if not the script exits
######

array=( t2.nano t2.micro m3.medium m4.large)
i=0
for instance in "${array[@]}"
do
	if [ $instance == $1 ]; then
		break
	fi 
	((i++))
done

if [ "$i" -eq 4 ]; then
	echo "Not valid instance type"
	exit
else
	echo "Valid instance type"
fi


######
###### The below block of code creates 3 IAM Groups
######

aws iam create-group --group-name devOps
aws iam create-group --group-name backendDev
aws iam create-group --group-name frontendDev

echo "Creating IAM Groups...."
sleep 1

######
###### The below block of code creates a customized IAM policy for Front End Developers to have full access on website S3 bucket
######

aws iam create-policy --policy-name oss-web-front-policy --policy-document file://oss-website1-policy.json

echo "creating customized IAM policy .... "
sleep 1

######
###### The below block of code attaches IAM Policies to the IAM Groups
######

aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --group-name devOps

aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --group-name backendDev

aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/oss-web-front-policy --group-name frontendDev

echo "Attaching IAM Groups Policies ...."
sleep 1

#######
###### The below block of code creates a Launch Configuration
###### 

aws autoscaling create-launch-configuration --launch-configuration-name yeaminOSS-launch-config --key-name MySydneyKeyPair --security-groups ec2SecurityGroup --iam-instance-profile S3-Admin-Access --image-id ami-8536d6e7 --instance-type `echo $1`

echo "Creating Launch Configuration...."
sleep 3

#######
###### The below block of code creates an Auto Scaling Group
######

aws autoscaling create-auto-scaling-group --auto-scaling-group-name yeaminOss-ASG --launch-configuration-name yeaminOSS-launch-config --min-size 1 --max-size 3 --availability-zones ap-southeast-2a ap-southeast-2b --tags ResourceId=yeaminOss-ASG,ResourceType=auto-scaling-group,Key=Name,Value=yeaminOss-ASG

echo "Creating Auto Scaling Group...."
sleep 3

#######
###### The below block of code creates 2 S3 buckets in Sydney region
######

aws s3api create-bucket --bucket oss-logs1 --region ap-southeast-2 --create-bucket-configuration LocationConstraint=ap-southeast-2

sleep 1

aws s3api create-bucket --bucket oss-website1 --acl public-read --region ap-southeast-2 --create-bucket-configuration LocationConstraint=ap-southeast-2

echo "Creating S3 Buckets ..."
sleep 2

#######
###### The below block of code creates an RDS MySQL database 2
######

aws rds create-db-instance --db-name yeaminoss --db-instance-identifier yeaminoss --allocated-storage 10 --db-instance-class db.t2.small --engine mysql --master-username yeamin --master-user-password yeamin123 --vpc-security-group-ids sg-885bc7ee

echo "Creating MySQL RDS Instance ..."
sleep 10


#######
###### The below block of code allows Security Group of the EC2 for inbound traffic towards the Security Group of the RDS for port 3306
######

aws ec2 authorize-security-group-ingress --group-id sg-885bc7ee --protocol tcp --port 3306 --source-group sg-7da13d1b

echo "Allowing Ingress traffic in RDS SG for port 3306 ..."
sleep 10 
