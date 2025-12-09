# S3 bucket for CircleCI Docker layer caching
module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "${local.cluster_name}-cci"
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = true
  }

  tags = local.cost_center_tags
}

# Pod identity for CircleCI DLC S3 access
module "circleci_dlc_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.4.1"

  name = "${module.eks.cluster_name}-cci-s3"

  attach_custom_policy = true
  source_policy_documents = [
    jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "S3BucketAccess"
          Effect = "Allow"
          Action = [
            "s3:PutAnalyticsConfiguration",
            "s3:GetObjectVersionTagging",
            "s3:CreateBucket",
            "s3:GetObjectAcl",
            "s3:GetBucketObjectLockConfiguration",
            "s3:DeleteBucketWebsite",
            "s3:PutLifecycleConfiguration",
            "s3:GetObjectVersionAcl",
            "s3:PutObjectTagging",
            "s3:DeleteObject",
            "s3:DeleteObjectTagging",
            "s3:GetBucketPolicyStatus",
            "s3:GetObjectRetention",
            "s3:GetBucketWebsite",
            "s3:GetJobTagging",
            "s3:DeleteObjectVersionTagging",
            "s3:PutObjectLegalHold",
            "s3:GetObjectLegalHold",
            "s3:GetBucketNotification",
            "s3:PutBucketCORS",
            "s3:GetReplicationConfiguration",
            "s3:ListMultipartUploadParts",
            "s3:PutObject",
            "s3:GetObject",
            "s3:PutBucketNotification",
            "s3:DescribeJob",
            "s3:PutBucketLogging",
            "s3:GetAnalyticsConfiguration",
            "s3:PutBucketObjectLockConfiguration",
            "s3:GetObjectVersionForReplication",
            "s3:GetLifecycleConfiguration",
            "s3:GetInventoryConfiguration",
            "s3:GetBucketTagging",
            "s3:PutAccelerateConfiguration",
            "s3:DeleteObjectVersion",
            "s3:GetBucketLogging",
            "s3:ListBucketVersions",
            "s3:ReplicateTags",
            "s3:RestoreObject",
            "s3:ListBucket",
            "s3:GetAccelerateConfiguration",
            "s3:GetBucketPolicy",
            "s3:PutEncryptionConfiguration",
            "s3:GetEncryptionConfiguration",
            "s3:GetObjectVersionTorrent",
            "s3:AbortMultipartUpload",
            "s3:PutBucketTagging",
            "s3:GetBucketRequestPayment",
            "s3:GetAccessPointPolicyStatus",
            "s3:GetObjectTagging",
            "s3:GetMetricsConfiguration",
            "s3:PutBucketVersioning",
            "s3:GetBucketPublicAccessBlock",
            "s3:ListBucketMultipartUploads",
            "s3:PutMetricsConfiguration",
            "s3:PutObjectVersionTagging",
            "s3:GetBucketVersioning",
            "s3:GetBucketAcl",
            "s3:PutInventoryConfiguration",
            "s3:GetObjectTorrent",
            "s3:PutBucketWebsite",
            "s3:PutBucketRequestPayment",
            "s3:PutObjectRetention",
            "s3:GetBucketCORS",
            "s3:GetBucketLocation",
            "s3:GetAccessPointPolicy",
            "s3:GetObjectVersion",
            "s3:GetAccessPoint",
            "s3:GetAccountPublicAccessBlock",
            "s3:ListAllMyBuckets",
            "s3:ListAccessPoints",
            "s3:ListJobs"
          ]
          Resource = [
            module.s3_bucket.s3_bucket_arn,
            "${module.s3_bucket.s3_bucket_arn}/*"
          ]
        },
        {
          Sid    = "AssumeObjectStorageRole"
          Effect = "Allow"
          Action = [
            "iam:GetRole",
            "sts:AssumeRole"
          ]
          Resource = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${module.eks.cluster_name}-cci*"
          ]
        }
      ]
    })
  ]

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "circleci-server"
      service_account = "object-storage"
    }
  }

  tags = local.cost_center_tags
}

# Security group for CircleCI machine provisioner
resource "aws_security_group" "circleci_machine_provisioner" {
  name        = "circleci-machine-provisioner-sg"
  description = "CircleCI machine provisioner security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH access for CircleCI jobs"
    from_port   = 54782
    to_port     = 54782
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.cost_center_tags,
    {
      Name = "circleci-machine-provisioner-sg"
    }
  )
}

# Pod identity to allow CCI machien provisioner to
module "circleci_machine_provisioner_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.4.1"

  name = "${module.eks.cluster_name}-cci-provisioner"

  attach_custom_policy = true
  source_policy_documents = [
    jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "ec2:RunInstances",
          "Effect" : "Allow",
          "Resource" : [
            "arn:aws:ec2:*::image/*",
            "arn:aws:ec2:*::snapshot/*",
            "arn:aws:ec2:*:*:key-pair/*",
            "arn:aws:ec2:*:*:launch-template/*",
            "arn:aws:ec2:*:*:network-interface/*",
            "arn:aws:ec2:*:*:placement-group/*",
            "arn:aws:ec2:*:*:security-group/${aws_security_group.circleci_machine_provisioner.id}",
            "arn:aws:ec2:*:*:volume/*"
          ]
        },
        {
          "Action" : "ec2:RunInstances",
          "Effect" : "Allow",
          "Resource" : [
            "arn:aws:ec2:*:*:subnet/${module.vpc.public_subnets[0]}",
            "arn:aws:ec2:*:*:subnet/${module.vpc.public_subnets[1]}",
            "arn:aws:ec2:*:*:subnet/${module.vpc.public_subnets[2]}",
          ]
        },
        {
          "Action" : "ec2:RunInstances",
          "Effect" : "Allow",
          "Resource" : "arn:aws:ec2:*:*:instance/*",
          "Condition" : {
            "StringEquals" : {
              "aws:RequestTag/ManagedBy" : "circleci-machine-provisioner"
            }
          }
        },
        {
          "Action" : [
            "ec2:Describe*"
          ],
          "Effect" : "Allow",
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ec2:CreateTags"
          ],
          "Resource" : "arn:aws:ec2:*:*:*/*",
          "Condition" : {
            "StringEquals" : {
              "ec2:CreateAction" : "RunInstances"
            }
          }
        },
        {
          "Action" : [
            "ec2:RunInstances",
            "ec2:StartInstances",
            "ec2:StopInstances",
            "ec2:TerminateInstances"
          ],
          "Effect" : "Allow",
          "Resource" : "arn:aws:ec2:*:*:instance/*",
          "Condition" : {
            "StringLike" : {
              "ec2:Subnet" : [
                "arn:aws:ec2:*:*:subnet/${module.vpc.public_subnets[0]}",
                "arn:aws:ec2:*:*:subnet/${module.vpc.public_subnets[1]}",
                "arn:aws:ec2:*:*:subnet/${module.vpc.public_subnets[2]}",
              ]
            },
            "StringEquals" : {
              "ec2:ResourceTag/ManagedBy" : "circleci-machine-provisioner"
            }
          }
        }
      ]
    })
  ]

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "circleci-server"
      service_account = "machine-provisioner"
    }
  }

  tags = local.cost_center_tags
}
