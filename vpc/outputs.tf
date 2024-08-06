# vpc id
output "min-vpc-id" {
  value = aws_vpc.this.id
}
# 프라이빗 서브넷 id
output "pri-sub1-id" {
  value = aws_subnet.pri_sub1.id
}
output "pri-sub2-id" {
  value = aws_subnet.pri_sub2.id
}
# 퍼블릭 서브넷 id
output "pub-sub1-id" {
  value = aws_subnet.pub_sub1.id
}
output "pub-sub2-id" {
  value = aws_subnet.pub_sub2.id
}
