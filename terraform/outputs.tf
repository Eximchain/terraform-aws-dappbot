output "api_dns" {
    value = "${aws_api_gateway_domain_name.domain.domain_name}"
}

output "cloudfront_cert_arn" {
    value = "${element(coalescelist(aws_acm_certificate.cloudfront_cert.*.arn, list("")), 0)}"
}