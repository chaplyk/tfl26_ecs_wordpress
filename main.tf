provider "aws" {
    region = "eu-west-2"
}

resource "aws_ecs_cluster" "tfl_26" {
  name = "tfl_26"
}

data "aws_ami" "ecs_optimized" {
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-2.0.20190709-x86_64-ebs"]
  }
   owners = ["amazon"]
}

resource "aws_security_group" "allow_all_tfl_26" {
name = "allow_all_tfl_26"
ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 0
    to_port = 65535
    protocol = "tcp"
  }
  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}

resource "aws_launch_configuration" "tfl_26_launch_configuration" {
  name                 = "tfl_26_launch_configuration"
  image_id             = "${data.aws_ami.ecs_optimized.id}"
  iam_instance_profile = "ecsInstanceRole"
  key_name = "bohdan_chaplyk"
  security_groups = ["${aws_security_group.allow_all_tfl_26.name}"]
  user_data            = "${file("join_tfl_26_cluster.sh")}"
  instance_type = "t2.micro"
}

resource "aws_autoscaling_group" "tfl_26_autoscaling_group" {
  name                 = "tfl_26"
  launch_configuration = "${aws_launch_configuration.tfl_26_launch_configuration.name}"
  availability_zones = ["eu-west-2a"]
  min_size         = 2
  max_size         = 2
}

#resource "aws_autoscaling_policy" "tfl_26_policy" {
#  name                      = "tfl_26_policy"
#  policy_type               = "TargetTrackingScaling"
#  autoscaling_group_name    = "${aws_autoscaling_group.tfl_26_autoscaling_group.name}"

#  target_tracking_configuration {
#    predefined_metric_specification {
#      predefined_metric_type = "ASGAverageCPUUtilization"
#    }
#    target_value = 85.0
#  }
#}

resource "aws_ecs_task_definition" "wordpress_task" {
  family                = "wordpress"
  container_definitions = "${file("wordpress.json")}"

  volume {
    name = "service-storage"
  }
}

resource "aws_ecs_service" "wordpress" {
  name            = "wordpress"
  cluster         = "${aws_ecs_cluster.tfl_26.id}"
  task_definition = "${aws_ecs_task_definition.wordpress_task.arn}"
  desired_count   = 2
  load_balancer {
    target_group_arn = "${aws_alb_target_group.tfl26.arn}"
    container_name   = "wordpress"
    container_port   = 80
  }
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_default_subnet" "az2" {
  availability_zone = "eu-west-2a"

  tags = {
    Name = "Default subnet for eu-west-2a"
  }
}

resource "aws_alb" "alb" {
 name            = "alb-tfl26"
 internal        = false
 subnets            = ["${aws_default_subnet.az2.id}", "subnet-06dc694a25cdc40c3"]
 security_groups = ["${aws_security_group.allow_all_tfl_26.id}"]
}

resource "aws_alb_target_group" "tfl26" {
 name     = "tg-alb-tfl26"
 port     = "80"
 protocol = "HTTP"
 vpc_id = "${aws_default_vpc.default.id}"
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = "${aws_alb.alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.tfl26.arn}"
    type             = "forward"
  }
}