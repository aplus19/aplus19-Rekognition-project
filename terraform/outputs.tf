output "image_inputs_bucket" {
  description = "Upload your images here"
  value       = aws_s3_bucket.image_inputs.bucket
}

output "analysis_outputs_bucket" {
  description = "JSON results are saved here"
  value       = aws_s3_bucket.analysis_outputs.bucket
}

output "web_frontend_url" {
  description = "Your website URL"
  value       = "http://${aws_s3_bucket_website_configuration.web_frontend_site.website_endpoint}"
}

output "api_gateway_url" {
  description = "Paste this into app.js CONFIG.API_URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.image_analysis.function_name
}