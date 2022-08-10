################################################################################
# Security Group Module
################################################################################
module "polkadot_collator_node_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-collator-sg"
  description = "Security group for use with polkadot EC2 instance"
  vpc_id      = module.polkadot_vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"] 
  egress_rules        = ["all-all"]

  ingress_with_cidr_blocks = [
    {
      from_port   = 30333
      to_port     = 30334
      protocol    = "tcp"
      description = "collatornode ports"
      cidr_blocks = "10.0.0.0/16"
    },    
    {
      from_port   = 9933
      to_port     = 9944
      protocol    = "tcp"
      description = "collatornode ports"
      cidr_blocks = "10.0.0.0/16"
    },
    {
      from_port   = 8833
      to_port     = 8844
      protocol    = "tcp"
      description = "collatornode ports"
      cidr_blocks = "10.0.0.0/16"
    },

  ]

  tags = local.tags
}
################################################################################
# EC2 Module
################################################################################
module "polkadot_collator_node" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "${local.name}-collatornode"

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro" #"c5.large"
  key_name               = module.key_pair.key_pair_name
  monitoring             = true
  vpc_security_group_ids = [module.polkadot_collator_node_security_group.security_group_id]
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
      node_type = "collatornode"
  }
}

################################################################################
# EBS / Volume attachments
################################################################################
resource "aws_volume_attachment" "collator_node" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.polkadot_collator_node_ebs.id
  instance_id =  module.polkadot_collator_node.id 
}

resource "aws_ebs_volume" "polkadot_collator_node_ebs" {
  availability_zone = local.availability_zone
  size              = 100

  tags = local.tags
}
