variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resource names"
  type        = string
  default     = "project2-rekognition"
}

variable "min_confidence" {
  description = "Minimum confidence % for Rekognition detections"
  type        = number
  default     = 70
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 60
}

variable "lambda_memory" {
  description = "Lambda memory in MB"
  type        = number
  default     = 256
}