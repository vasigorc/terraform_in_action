output "vpc" {
  value = module.vpc
}

output "sg" {
  value = {
    lib    = module.lb_sg.security_group.id
    db     = module.db_sg.security_group.id
    websvr = module.websvr_sg.security_group.id
  }
}
