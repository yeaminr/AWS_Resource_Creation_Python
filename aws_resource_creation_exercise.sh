#!/bin/bash

#Script Name: aws_resource_creation_exercise.sh
#Author: Yeamin Rajeev (yeamin.rajeev@gmail.com)
#Version: 2.0
#Description: This Bash script creates a number of AWS resources using the AWS CLI run on Linux. The version 2.0 adds error handling by using the Bash exit status for each
#             command and exits the script if any error occurs. Further improvement of rollback is planned based on this error handling mechanism.
#Dependencies: Please check the requirements.txt file for details.

#### Below variables are used for the command to  allow EC2 SG to access RDS SG
rds_sg="sg-885bc7ee"
ec2_sg="sg-7da13d1b"

### Below IAM role is used in Launch Config command
ec2_IAM_Role="S3-Admin-Access"

######
###### The below block of code checks if the 1st argument $1 is a valid EC2 instance type name, if not the script exits
######

array=( t1.micro t2.nano t2.micro t2.small t2.medium t2.large m1.small m1.medium m1.large m1.xlarge m2.xlarge m2.2xlarge m2.4xlarge m3.medium m3.large m3.xlarge)

i=0
for instance in "${array[@]}"
do
	if [ $instance == $1 ]; then
		break
	fi
	((i++))
done

if [ "$i" -eq 16 ]; then
	echo "Not valid instance type"
	exit
else
	echo "Valid instance type"
fi

count=0
######
###### The below block of code creates 3 IAM Groups
######

aws iam create-group --group-name devOps
exit_status=`echo $?`
if [ $exit_status -eq 0 ]; then
       echo "Creating IAM Group...."
       sleep 1
else
       echo "There was an error, please check the CLI command create-group. Exiting...."
       exit
fi
(( count++ ))

aws iam create-group --group-name backendDev
exit_status=`echo $?`
if [ $exit_status -eq 0 ]; then
       echo "Creating IAM Group...."
       sleep 1
else
       echo "There was an error, please check the CLI command create-group. Exiting...."
       exit
fi
(( count++ ))

aws iam create-group --group-name frontendDev
exit_status=`echo $?`
if [ $exit_status -eq 0 ]; then
       echo "Creating IAM Group...."
       sleep 1
else
       echo "There was an error, please check the CLI command create-group. Exiting...."
       exit
fi
(( count++ ))

######
###### The below block of code creates a customized IAM policy for Front End Developers to have full access on website S3 bucket
######

aws iam create-policy --policy-name oss-web-front-policy --policy-document file://oss-website1-policy.json
exit_status=`echo $?`
if [ $exit_status -eq 0 ]; then
       echo "Creating IAM Policy...."
       sleep 1
else
       echo "There was an error, please check the CLI command create-policy. Exiting...."
       exit
fi
(( count++ ))

######
###### The below block of code attaches IAM Policies to the IAM Groups
######

aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --group-name devOps
exit_status=`echo $?`
if [ $exit_status -eq 0 ]; then
       echo "Attaching IAM Group Policy ...."
       sleep 1
else
       echo "There was an error, please check the CLI command attach-group-policy. Exiting...."
       exit
fi
(( count++ ))

aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --group-name backendDev
exit_status=`echo $?`
if [ $exit_status -eq 0 ]; then
       echo "Attaching IAM Group Policy ...."
       sleep 1
else
       echo "There was an error, please check the CLI command attach-group-policy. Exiting...."
       exit
fi
(( count++ ))

aws iam attach-group-policy --policy-arn arn:aws:iam::`echo $2`:policy/oss-web-front-policy --group-name frontendDev
exit_status=`echo $?`
if [ $exit_status -eq 0 ]; then
       echo "Attaching IAM Group Policy ...."
       sleep 1
else
       echo "There was an error, please check the CLI command attach-group-policy. Exiting...."
       exit
fi
(( count++ ))

#######
###### The below block of code creates a Launch Configuration
######

aws autoscaling create-launch-configuration --launch-configuration-name yeaminOSS-launch-config --key-name MySydneyKeyPair --security-groups ec2SecurityGroup --iam-instance-profile `echo $ec2_IAM_Role` --image-id ami-8536d6e7 --instance-type `echo $1`
exit_status=`echo $?`
if [ $exit_status -eq 0 ]; then
       echo "Creating Launch Configuration...."
       sleep 3
else
       echo "There was an error, please check the CLI command create-launch-configuration. Exiting...."
       exit
fi
(( count++ ))

#######
###### The below block of code creates an Auto Scaling Group
######

aws autoscaling create-auto-scaling-group --auto-scaling-group-name yeaminOss-ASG --launch-configuration-name yeaminOSS-launch-config --min-size 1 --max-size 3 --availability-zones ap-southeast-2a ap-southeast-2b --tags ResourceId=yeaminOss-ASG,ResourceType=auto-scaling-group,Key=Name,Value=yeaminOss-ASG
exit_status=`echo $?`
if [ $exit_status -eq 0 ]; then
	echo "Creating Auto Scaling Group...."
	sleep 3
else
	echo "There was an error, please check the CLI command create-auto-scaling-group. Exiting...."
	exit
fi
(( count++ ))

#######
###### The below block of code puts 2 Auto Scaling Policies (simple) into the Autoscaling Group
######

aws autoscaling put-scaling-policy --auto-scaling-group-name yeaminOss-ASG --policy-name simpleScaleUp --scaling-adjustment 1 --adjustment-type ChangeInCapacity --cooldown 60
exit_status=`echo $?`
if [ $exit_status -eq 0 ]; then
        echo "Putting Auto Scaling Policy...."
        sleep 1
else
      	echo "There was an error, please check the CLI command put-scaling-policy. Exiting...."
       exit
fi
(( count++ ))

aws autoscaling put-scaling-policy --auto-scaling-group-name yeaminOss-ASG --policy-name simpleScaleDown --scaling-adjustment -1 --adjustment-type ChangeInCapacity --cooldown 60
exit_status=`echo $?`
if [ $exit_status -eq 0 ]; then
        echo "Putting Auto Scaling Policy...."
        sleep 1
else
    	echo "There was an error, please check the CLI command put-scaling-policy. Exiting...."
       exit
fi
(( count++ ))

#######
###### The below block of code creates 2 S3 buckets in Sydney region
######

aws s3api create-bucket --bucket oss-logs1 --region ap-southeast-2 --create-bucket-configuration LocationConstraint=ap-southeast-2
exit_status=`echo $?`
if [ $exit_status -eq 0 ]; then
        echo "Creating S3 Bucket...."
        sleep 1
else
    	echo "There was an error, please check the CLI command create-bucket. Exiting...."
       exit
fi
(( count++ ))

aws s3api create-bucket --bucket oss-website1 --acl public-read --region ap-southeast-2 --create-bucket-configuration LocationConstraint=ap-southeast-2
exit_status=`echo $?`
if [ $exit_status -eq 0 ]; then
        echo "Creating S3 Bucket...."
        sleep 1
else
        echo "There was an error, please check the CLI command create-bucket. Exiting...."
       exit
fi
(( count++ ))

#######
###### The below block of code creates an RDS MySQL database
######

aws rds create-db-instance --db-name yeaminoss --db-instance-identifier yeaminoss --allocated-storage 10 --db-instance-class db.t2.small --engine mysql --master-username yeamin --master-user-password yeamin123 --vpc-security-group-ids sg-885bc7ee
exit_status=`echo $?`
if [ $exit_status -eq 0 ]; then
        echo "Creating MySQL RDS Instance ...."
        sleep 10
else
        echo "There was an error, please check the CLI command create-db-instance. Exiting...."
       exit
fi
(( count++ ))

#######
###### The below block of code allows Security Group of the EC2 for inbound traffic towards the Security Group of the RDS for port 3306
######

aws ec2 authorize-security-group-ingress --group-id `echo $rds_sg` --protocol tcp --port 3306 --source-group `echo $ec2_sg`
exit_status=`echo $?`
if [ $exit_status -eq 0 ]; then
        echo "Allowing Ingress traffic in RDS SG for port 3306...."
        sleep 3
else
        echo "There was an error, please check the CLI command create-bucket. Exiting...."
       exit
fi
(( count++ ))

echo "Stack Creation Successful."
echo
