#!/usr/bin/python

import boto3
import json
import sys
import time

iam_client = boto3.client('iam')
# The below block of code creates 3 IAM groups

group_names = ['DevOps', 'FrontEndDev', 'BackEndDev']
for group_name in group_names:
	response = iam_client.create_group(
     		GroupName=group_name
	)
	if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
		print ("Error while creating group. Exiting...")
		sys.exit(1)
	else:
		print ("Successfully Created IAM Group.")


#The below block of code checks if argv[1] is a valid EC2 Instance type
#If not valid instance type, the script selects 't2.micro' by default

valid_instances = ['t1.micro', 't2.nano', 't2.micro', 't2.small', 't2.medium', 't2.large', 'm1.small', 'm1.medium', 'm1.large', \
'm1.xlarge', 'm2.xlarge', 'm2.2xlarge', 'm2.4xlarge', 'm3.medium', 'm3.large', 'm3.xlarge', 'm3.2xlarge', 'c4.large', 'c4.xlarge', 'c4.2xlarge', \
'c4.4xlarge', 'c4.8xlarge', 'c3.large', 'c3.xlarge', 'c3.2xlarge', 'c3.4xlarge', 'c3.8xlarge', 'g3.4xlarge', 'g3.8xlarge', 'g3.16xlarge']
i=0
for instance in valid_instances:
        if (sys.argv[1] == instance):
                break;
        i=i+1

if (i==30):
	print ("Not a valid instance type, using t2.micro.")
        instance_type='t2.micro'
else:
     	print ("Valid instance type.")
        instance_type = sys.argv[1]


ec2_client = boto3.client('ec2')
#Below block of code Creates 2 security groups

response = ec2_client.create_security_group(
    Description='ec2-sg',
    GroupName='ec2-sg',
)
if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        print ("Error while creating Security Group. Exiting...")
        sys.exit(1)
else:
     	print ("Successfully Created Security Group.")
ec2_sg_id=response['GroupId']

response = ec2_client.create_security_group(
    Description='rds-sg',
    GroupName='rds-sg',
)
if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        print ("Error while creating Security Group. Exiting...")
        sys.exit(1)
else:
     	print ("Successfully Created Security Group.")
rds_sg_id=response['GroupId']
time.sleep(1)

#The below block of code allows port 3306 (MySQL RDS) traffic from ec2-sg to rds-sg

response = ec2_client.authorize_security_group_ingress(
    GroupId=rds_sg_id,
    IpPermissions=[
        {'IpProtocol': 'tcp',
        'FromPort': 3306,
        'ToPort': 3306,
        'UserIdGroupPairs': [{ 'GroupId': ec2_sg_id }] }
    ],

)
if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        print ("Error while Allowing Security Group Ingress. Exiting...")
        sys.exit(1)
else:
     	print ("Successfully Allowed port 3306 from ec2-sg to rds-sg.")
time.sleep(1)

asg_client = boto3.client('autoscaling')
# The below block of code creates a Launch Configuration

response = asg_client.create_launch_configuration(
    KeyName='MySydneyKeyPair',
    ImageId='ami-8536d6e7',
    InstanceType=instance_type,
    LaunchConfigurationName='yeamin-launch-config',
    SecurityGroups=[
        ec2_sg_id,
    ],
)
if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        print ("Error while creating Launch Configuration. Exiting...")
        sys.exit(1)
else:
        print ("Successfully Created Launch Configuration.")
time.sleep(1)

# The below block of code creates an Auto Scaling Group

response = asg_client.create_auto_scaling_group(
    AutoScalingGroupName='yeamin-asg',
    LaunchConfigurationName='yeamin-launch-config',
    MaxSize=3,
    MinSize=1,
    AvailabilityZones=[
        'ap-southeast-2a',
	'ap-southeast-2b',
    ],
    Tags=[
        {
	    'ResourceId': 'yeamin-asg',
            'ResourceType': 'auto-scaling-group',
            'Key': 'Name',
            'Value': 'yeamin-ASG',
        },
    ],
)
if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        print ("Error while creating Auto Scaling Group. Exiting...")
        sys.exit(1)
else:
     	print ("Successfully Created Auto Scaling Group.")
time.sleep(1)

# The below block of code puts 2 Auto Scaling Policies

response = asg_client.put_scaling_policy(
    AdjustmentType='ChangeInCapacity',
    AutoScalingGroupName='yeamin-asg',
    PolicyName='simple_scale_up',
    ScalingAdjustment=1,
)
if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        print ("Error while putting Auto Scaling Policy. Exiting...")
        sys.exit(1)
else:
     	print ("Successfully Created Auto Scaling Policy.")

scale_up_arn=response['PolicyARN']

response = asg_client.put_scaling_policy(
    AdjustmentType='ChangeInCapacity',
    AutoScalingGroupName='yeamin-asg',
    PolicyName='simple_scale_down',
    ScalingAdjustment=-1,
)
if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        print ("Error while putting Auto Scaling Policy. Exiting...")
        sys.exit(1)
else:
     	print ("Successfully Created Auto Scaling Policy.")
scale_down_arn=response['PolicyARN']
time.sleep(1)

cloudwatch_client = boto3.client('cloudwatch')
# The below block of code puts 2 Cloudwatch Alarms into the Auto Scaling Policies

response = cloudwatch_client.put_metric_alarm(
    AlarmName='cpu-mon-high',
    AlarmDescription='Alarm when CPU exceeds 75%',
    AlarmActions=[
        scale_up_arn,
    ],
    MetricName='CPUUtilization',
    Namespace='AWS/EC2',
    Statistic='Average',
    Period=300,
    Unit='Percent',
    EvaluationPeriods=1,
    Threshold=75,
    ComparisonOperator='GreaterThanThreshold',
)
if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        print ("Error while creating CloudWatch Alarm. Exiting...")
        sys.exit(1)
else:
        print ("Successfully Created CloudWatch Alarm.")

response = cloudwatch_client.put_metric_alarm(
    AlarmName='cpu-mon-low',
    AlarmDescription='Alarm when CPU descends 25%',
    AlarmActions=[
        scale_down_arn,
    ],
    MetricName='CPUUtilization',
    Namespace='AWS/EC2',
    Statistic='Average',
    Period=300,
    Unit='Percent',
    EvaluationPeriods=1,
    Threshold=25,
    ComparisonOperator='LessThanThreshold',
)
if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        print ("Error while creating CloudWatch Alarm. Exiting...")
        sys.exit(1)
else:
     	print ("Successfully Created CloudWatch Alarm.")
time.sleep(1)

s3_client = boto3.client('s3')
#The below block of code creates 2 S3 Buckets

response = s3_client.create_bucket(
    Bucket='yeamin-logs',
    CreateBucketConfiguration={
        'LocationConstraint': 'ap-southeast-2'
    },
)

if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        print ("Error while creating S3 Bucket. Exiting...")
        sys.exit(1)
else:
     	print ("Successfully Created S3 Bucket.")
time.sleep(1)

response = s3_client.create_bucket(
    ACL='public-read',
    Bucket='yeamin-website',
    CreateBucketConfiguration={
        'LocationConstraint': 'ap-southeast-2'
    },
)

if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        print ("Error while creating S3 Bucket. Exiting...")
        sys.exit(1)
else:
     	print ("Successfully Created S3 Bucket.")

#The below block of code creates IAM policies to access Logs Bucket

logs_read_policy = {
    "Version": "2012-10-17",
    "Statement": [
        {
             "Effect": "Allow",
             "Action": "s3:GetObject",
             "Resource": "arn:aws:s3:::yeamin-logs/*"
        }
    ]
}
response = iam_client.create_policy(
    PolicyName='logs-read-policy',
    PolicyDocument=json.dumps(logs_read_policy)
)
if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        print ("Error while creating IAM Policy. Exiting...")
        sys.exit(1)
else:
        print ("Successfully Created IAM Policy.")
logs_read_policy_arn=response['Policy']['Arn']
time.sleep(1)

#The below block of code creates IAM policies to access Web Bucket

website_write_policy={
    "Version": "2012-10-17",
    "Statement": [
        {
             "Effect": "Allow",
             "Action": [
                "s3:DeleteObject",
                "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::yeamin-website/*"
        }
    ]
}
response = iam_client.create_policy(
    PolicyName='website-write-policy',
    PolicyDocument=json.dumps(website_write_policy)
)
if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        print ("Error while creating IAM Policy. Exiting...")
        sys.exit(1)
else:
     	print ("Successfully Created IAM Policy.")
web_write_policy_arn=response['Policy']['Arn']
time.sleep(1)

#Below block of code attaches the policies to the IAM groups created earlier

group_names=['BackEndDev', 'DevOps']
for group_name in group_names:
	response = iam_client.attach_group_policy(
    		GroupName=group_name,
    		PolicyArn=logs_read_policy_arn,
	)
	if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        	print ("Error while attaching IAM Policy. Exiting...")
        	sys.exit(1)
	else:
        	print ("Successfully Attached IAM Policy to Group.")

response = iam_client.attach_group_policy(
        GroupName='FrontEndDev',
        PolicyArn=web_write_policy_arn,
)
if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        print ("Error while attaching IAM Policy. Exiting...")
        sys.exit(1)
else:
     	print ("Successfully Attached IAM Policy to Group.")
time.sleep(1)

rds_client = boto3.client('rds')
#The below block of code creates a MySQL RDS instance

response = rds_client.create_db_instance(
    DBName='yeamin',
    DBInstanceIdentifier='yeamin',
    AllocatedStorage=10,
    DBInstanceClass='db.t2.small',
    Engine='mysql',
    MasterUsername='yeamin',
    MasterUserPassword='yeamin321',
    VpcSecurityGroupIds=[
        rds_sg_id,
    ],
)
if (response['ResponseMetadata']['HTTPStatusCode'] != 200):
        print ("Error while creating RDS. Exiting...")
        sys.exit(1)
else:
     	print ("Successfully created RDS Instance.")

print ("-------")
print "The Python script completed successfully"

