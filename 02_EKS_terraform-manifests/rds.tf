# resource "aws_db_subnet_group" "rds_db_subnet_group" {
#   name       = "rds_subnet_group"
#   subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
# }


# resource "aws_db_instance" "aws_rds" {
#   allocated_storage    = 10
#   db_name              = "mydb101"
#   engine               = "mysql"
#   engine_version       = "8.0"
#   instance_class       = "db.t3.micro"
#   db_subnet_group_name= aws_db_subnet_group.rds_db_subnet_group.name
#   vpc_security_group_ids=[aws_security_group.allow_eks_traffic.id]
#   username             = "mydbadmin"
#   password             = "kalyandb101"
#   parameter_group_name = "default.mysql8.0"
#   skip_final_snapshot  = true
# }


# resource "aws_security_group" "allow_eks_traffic" {
#   name        = "allow_eks_traffic"
#   description = "Allow eks inbound traffic "
#   vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

# }


# resource "aws_vpc_security_group_ingress_rule" "allow_eks_security_group" {
#   security_group_id = aws_security_group.allow_eks_traffic.id
#   from_port         = 3306
#   ip_protocol       = "tcp"
#   to_port           = 3306
#   referenced_security_group_id=aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
# }



