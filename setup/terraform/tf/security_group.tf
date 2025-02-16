resource "aws_security_group" "workshop_cluster_sg" {
  name_prefix = "${var.owner}-${var.name_prefix}-cluster-sg-"
  description = "Allow ingress connections from the user public IP"
  vpc_id      = (var.vpc_id != "" ? var.vpc_id : aws_vpc.vpc[0].id)

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.owner}-${var.name_prefix}-cluster-sg"
    owner   = var.owner
    project = var.project
    enddate = var.enddate
  }
}

resource "aws_security_group" "workshop_web_sg" {
  name_prefix = "${var.owner}-${var.name_prefix}-web-sg-"
  description = "Allow ingress connections from the user public IP"
  vpc_id      = (var.vpc_id != "" ? var.vpc_id : aws_vpc.vpc[0].id)

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = distinct(concat(["${var.my_public_ip}/32"], var.extra_cidr_blocks))
    self        = true
  }

  tags = {
    Name    = "${var.owner}-${var.name_prefix}-web-sg"
    owner   = var.owner
    project = var.project
    enddate = var.enddate
  }
}

resource "aws_security_group_rule" "workshop_cluster_extra_sg_rule" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = distinct(concat(["${var.my_public_ip}/32"], var.extra_cidr_blocks))
  security_group_id = aws_security_group.workshop_cluster_sg.id
}

resource "aws_security_group_rule" "workshop_self_sg_rule" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.workshop_cluster_sg.id
}

resource "aws_security_group_rule" "workshop_public_ips_sg_rule" {
  count             = (var.cluster_count > 0) ? 1 : 0
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [ for ip in (var.use_elastic_ip ? aws_eip.eip_cluster.*.public_ip : aws_instance.cluster.*.public_ip): "${ip}/32" ]
  security_group_id = aws_security_group.workshop_cluster_sg.id
}

resource "aws_security_group_rule" "workshop_cross_sg_rule" {
  count                    = length(local.sec_groups)
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = element(local.sec_groups, count.index)
  security_group_id        = aws_security_group.workshop_cluster_sg.id
}

resource "aws_security_group_rule" "workshop_cross_rule" {
  count                    = length(local.sec_groups)
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.workshop_cluster_sg.id
  security_group_id        = element(local.sec_groups, count.index)
}

data "aws_instances" "vpc_instances" {
  count = (var.vpc_id != "" ? 1 : 0)
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  instance_state_names = ["running"]
}

data "aws_instance" "vpc_instance" {
  count = (length(data.aws_instances.vpc_instances) > 0 ? length(distinct(data.aws_instances.vpc_instances.0.ids)) : 0)
  instance_id = element(data.aws_instances.vpc_instances.0.ids, count.index)
}

locals {
  sec_groups = (var.vpc_id == "" ? [] : [for sg in distinct(flatten(data.aws_instance.vpc_instance.*.vpc_security_group_ids)): sg if ! contains(var.managed_security_group_ids, sg)])
}
