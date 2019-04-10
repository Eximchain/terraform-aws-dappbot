output "api_dns" {
    value = "${aws_api_gateway_domain_name.domain.domain_name}"
}