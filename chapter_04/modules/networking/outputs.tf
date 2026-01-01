output "vpc" {
  value = module.vpc
}

output "sg" {
  value = {
    lb     = aws_security_group.lb.id
    db     = aws_security_group.db.id
    websvr = aws_security_group.websvr.id
  }
}
