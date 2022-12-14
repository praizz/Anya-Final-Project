
################################################################################
# Security Group Module
################################################################################
module "polkadot_rpc_node_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-rpc-sg"
  description = "Security group for use with polkadot EC2 instance"
  vpc_id      = module.polkadot_vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp", "ssh-tcp"] 
  egress_rules        = ["all-all"]

  ingress_with_cidr_blocks = [
    {
      from_port   = 30333
      to_port     = 30334
      protocol    = "tcp"
      description = "rpc node ports"
      cidr_blocks = "10.0.0.0/16"
    },    
    {
      from_port   = 9933
      to_port     = 9944
      protocol    = "tcp"
      description = "rpc node ports"
      cidr_blocks = "10.0.0.0/16"
    },
    {
      from_port   = 8833
      to_port     = 8844
      protocol    = "tcp"
      description = "rpc node ports"
      cidr_blocks = "10.0.0.0/16"
    },

  ]

  tags = local.tags
}

################################################################################
# EC2 Module
################################################################################
module "polkadot_rpc_node" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  for_each = toset(local.rpc_nodes)

  name = each.key

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro" 
  key_name               = module.key_pair.key_pair_name
  monitoring             = true
  vpc_security_group_ids = [module.polkadot_rpc_node_security_group.security_group_id]
  subnet_id              = element(module.polkadot_vpc.public_subnets, 0)

 capacity_reservation_specification = {
    capacity_reservation_preference = "open"
  }

  enable_volume_tags = false
  root_block_device = [
    {
      encrypted   = true
      delete_on_termination = false
      volume_type = "gp3"
      throughput  = 200
      volume_size = 50
      tags = {
        Name = "my-root-block"
      }
    },
  ]

  tags = {
      node_type = "rpcnode"
  }
}

################################################################################
# EBS / Volume attachments
################################################################################
resource "aws_volume_attachment" "rpc_node" {
  for_each = module.polkadot_rpc_node

  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.polkadot_rpc_node_ebs[index(local.rpc_nodes, each.key)].id
  instance_id =  module.polkadot_rpc_node[each.key].id 
}

resource "aws_ebs_volume" "polkadot_rpc_node_ebs" {
  count = length(local.rpc_nodes)
  availability_zone = local.availability_zone
  size              = 100

  tags = local.tags
}

################################################################################
# LOADBALANCING
################################################################################
resource "aws_elb" "polkadot_rpc_node" {
  name               = "${local.name}-elb"
  /* availability_zones = data.aws_availability_zones.available.names */

  subnets = module.polkadot_vpc.public_subnets
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  # health_check {
  #   healthy_threshold   = 2
  #   unhealthy_threshold = 2
  #   timeout             = 3
  #   target              = "tcp:30334/"
  #   interval            = 30
  # }

  /* listener {
    instance_port      = 443
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    /* ssl_certificate_id = "arn:aws:iam::123456789012:server-certificate/certName" */
  /* }  */

  listener {
    instance_port     = 30333
    instance_protocol = "tcp"
    lb_port           = 30333
    lb_protocol       = "tcp"
  }
  listener {
    instance_port     = 30334
    instance_protocol = "tcp"
    lb_port           = 30334
    lb_protocol       = "tcp"
  }
  /* instances                   = [module.polkadot_rpc_node[each.key].id] */
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = local.tags
}
# elb attachment
resource "aws_elb_attachment" "polkadot_rpc_node" {
  for_each = module.polkadot_rpc_node

  elb      = aws_elb.polkadot_rpc_node.id
  instance = module.polkadot_rpc_node[each.key].id 
}

