output "db_config" {
  value = {
    user     = aws_db_instance.database.username
    password = aws_db_instance.database.password
    database = aws_db_instance.database.name
    hostname = aws_db_instance.database.address
    user     = aws_db_instance.database.port
  }
}
