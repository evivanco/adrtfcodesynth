# ======================================================
# Archivo fusionado (MAYOR, con arquitectura): modules\pcmt\cloudpcmt.tf
# Piezas Terraform en carpeta: 27
# ======================================================



# ======================================================
# Archivo original: compute.tf
# Carpeta: C:\Users\asus\cloned_repos\Abelaa\pcmt\deploy\terraform\modules\pcmt
# ======================================================

######################################################################
# Copyright (c) 2019, VillageReach
# Licensed under the Non-Profit Open Software License version 3.0.
# SPDX-License-Identifier: NPOSL-3.0
######################################################################

resource "aws_instance" "app" {
  provider               = aws.compute
  ami                    = data.aws_ami.ubuntu-latest.id
  instance_type          = var.instance-type
  key_name               = var.ec2-key-pair
  subnet_id              = var.subnet-id
  vpc_security_group_ids = ["${var.security-group-id}"]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root-volume-size
    delete_on_termination = "true"
  }

  tags = {
    Name        = "${var.tag-name}"
    BillTo      = "${var.tag-bill-to}"
    Type        = "${var.tag-type}"
    DeployGroup = "${var.app-deploy-group}"
  }

  volume_tags = {
    BillTo = "${var.tag-bill-to}"
    Type   = "${var.tag-type}"
  }

  lifecycle {
    ignore_changes = [
      ami,
    ]
  }
}

data "aws_ami" "ubuntu-latest" {
  provider    = aws.compute
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "null_resource" "deploy-docker" {
  depends_on = [aws_instance.app]
  triggers = {
    build_number = "${timestamp()}"
  }

  connection {
    user = "ubuntu"
    host = aws_instance.app.public_ip
  }

  provisioner "remote-exec" {
    inline = ["ls"]

    connection {
      type = "ssh"
      user = "ubuntu"
    }
  }

  provisioner "local-exec" {
    command = "../script/pcmt-ansible.sh ${aws_instance.app.public_ip} ${var.domain-name}"
  }
}


# ======================================================
# Archivo original: main.tf
# Carpeta: C:\Users\asus\cloned_repos\Abelaa\pcmt\deploy\terraform\modules\pcmt
# ======================================================

terraform {
  required_version = ">= 0.12.0"

  required_providers {
    aws = {
      version = ">= 3.1"
    }
  }
}

provider "aws" {
  alias = "compute"
}

provider "aws" {
  alias = "network"
}



# ======================================================
# Archivo original: network.tf
# Carpeta: C:\Users\asus\cloned_repos\Abelaa\pcmt\deploy\terraform\modules\pcmt
# ======================================================

######################################################################
# Copyright (c) 2019, VillageReach
# Licensed under the Non-Profit Open Software License version 3.0.
# SPDX-License-Identifier: NPOSL-3.0
######################################################################

resource "aws_route53_record" "main" {
  provider = aws.network
  zone_id  = var.route53-zone-id
  name     = var.domain-name
  type     = "A"
  ttl      = 300
  records  = ["${aws_instance.app.public_ip}"]
}


# ======================================================
# Archivo original: storage.tf
# Carpeta: C:\Users\asus\cloned_repos\Abelaa\pcmt\deploy\terraform\modules\pcmt
# ======================================================

resource "aws_s3_bucket" "backup" {
  provider = aws.compute
  bucket   = var.domain-name
  acl      = "private"

  tags = {
    Name   = "${var.tag-name}"
    BillTo = "${var.tag-bill-to}"
    Type   = "${var.tag-type}"
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    enabled = true
    noncurrent_version_transition {
      days          = var.backup-days-till-glacier
      storage_class = "GLACIER"
    }

    noncurrent_version_expiration {
      days = var.backup-days-till-expire
    }
  }
}


# ======================================================
# Archivo original: variables.tf
# Carpeta: C:\Users\asus\cloned_repos\Abelaa\pcmt\deploy\terraform\modules\pcmt
# ======================================================

variable "aws-region" {
  type        = string
  description = "AWS Region to use"
}

variable "tag-name" {
  type        = string
  description = "Name of the environment"
}

variable "tag-type" {
  type        = string
  description = "Type of deployment, dev, staging, producting, buildinf, etc"
}

variable "tag-bill-to" {
  type        = string
  description = "Which project to bill the provisioned resources"
  default     = "PCMT"
}

variable "root-volume-size" {
  type        = number
  description = "Size in GB of root volume"
  default     = "20"
}

variable "instance-type" {
  type        = string
  description = "Size in GB of root volume"
  default     = "t3a.small"
}

variable "app-deploy-group" {
  type        = string
  description = "Tags ec2 app instance for use by Ansible Playbooks."
  default     = "docker-hosts"
}

variable "ec2-key-pair" {
  type        = string
  description = "Name of EC2 key-pair for instance"
  default     = "pcmt-ec2"
}

variable "domain-name" {
  type        = string
  description = "AWS Route53 Domain Name"
}

variable "subnet-id" {
  type        = string
  description = "ID of subnet to launch EC2 into"
}

variable "route53-zone-id" {
  type        = string
  description = "ID of zone to insert record into"
}

variable "security-group-id" {
  type        = string
  description = "ID of security group to use for instance"
}

variable "backup-days-till-glacier" {
  type        = number
  description = "Days until backups are moved to glacier"
  default     = 15
}

variable "backup-days-till-expire" {
  type        = number
  description = "Days until backups expire - are deleted"
  default     = 30
}

variable "route53-provider" {
  type        = string
  description = "AWS provider to use for the DNS entry, only needed when >1 aws provider is in use"
  default     = "default"
}

