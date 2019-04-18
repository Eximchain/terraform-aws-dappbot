output "api_dns" {
    value = "${aws_api_gateway_domain_name.domain.domain_name}"
}

output "cloudfront_cert_arn" {
    value = "${aws_acm_certificate.cloudfront_cert.arn}"
}