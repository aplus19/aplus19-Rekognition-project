# 🔍 RekognitionAI — AWS Image Analysis & Product Safety Pipeline

A serverless image analysis and product safety scanning platform built on AWS. The system processes uploaded images through Amazon Rekognition for object detection, facial analysis, and OCR text extraction, storing structured JSON results in S3. Includes **ScanSafe** — a product safety scanner that detects expiry dates, FDA approval status, banned ingredients, and allergens from product labels.

## 🏗️ Architecture
                    +---------------------------+
                    |   Frontend (index.html)   |
                    |   Hosted on S3 Bucket     |
                    +-------------+-------------+
                                  |
                                  | POST /analyze (Base64 images)
                                  v
                    +---------------------------+
                    |      API Gateway          |
                    |      HTTP API             |
                    +-------------+-------------+
                                  |
                                  v
          +----------------------------------------------+
          |         Lambda: image-analysis-handler        |
          |                                              |
          |  1. analyze_base64 — Image Analysis          |
          |     - DetectLabels (objects, scenes)         |
          |     - DetectFaces (emotions, age, gender)    |
          |     - DetectText (OCR)                       |
          |                                              |
          |  2. scan_product — ScanSafe Scanner          |
          |     - Extract text from product label        |
          |     - Check expiry date                      |
          |     - Check FDA/regulatory approval          |
          |     - Analyze ingredients for banned items   |
          |     - Calculate safety score                 |
          |                                              |
          |  3. S3 Event Trigger — Auto Analysis         |
          |     - Triggered on image upload to S3        |
          |     - Saves JSON result to output bucket     |
          +----------------------------------------------+
                |                |               |
                v                v               v
          +---------+    +-------------+   +-----------+
          |   S3    |    | Rekognition |   |    S3     |
          | Inputs  |    |   Service   |   |  Outputs  |
          +---------+    +-------------+   +-----------+

## ☁️ AWS Services Used

| Service | Role |
| Amazon Rekognition | Core AI/ML — DetectLabels, DetectFaces, DetectText |
| AWS Lambda | Serverless compute — Python 3.10 handler |
| Amazon S3 | Three buckets: image inputs, analysis outputs, web frontend |
| API Gateway | HTTP API exposing POST /analyze endpoint with CORS |
| AWS IAM | Least-privilege execution role for Lambda |
| Amazon CloudWatch | Logs and monitoring for Lambda functions |
| Terraform | Infrastructure as Code — provisions all AWS resources |

## ✨ Features

### 🤖 AI Image Analysis
- **Label Detection** — Identifies objects, scenes, and concepts with confidence scores
- **Face Analysis** — Detects emotions, age range, gender, smile, and eyeglasses
- **Text Extraction (OCR)** — Reads and extracts all visible text from images

### 🛡️ ScanSafe — Product Safety Scanner
- **Expiry Date Detection** — Reads expiry dates and calculates days remaining or expired
- **FDA/Regulatory Approval** — Checks for Ghana FDA, NAFDAC, and other regulatory markers
- **Ingredient Safety Analysis** — Detects 14 banned substances, 15 warning ingredients, 12 allergens
- **Product Categorization** — Identifies Medicine, Food, Cosmetics, Baby Products, Automotive, and more
- **Safety Scoring** — Gives every product a score out of 100 with clear rating

### 🌐 Web Interface
- Professional dark UI with tab navigation (Home, Analyze, History, About, ScanSafe)
- Drag and drop image upload
- Real-time analysis results
- Analysis history stored locally
- Clear image button
- Mobile responsive design

## 📁 Project Structure

rekognition-project/
│
├── terraform/                  # Infrastructure as Code
│   ├── main.tf                 # S3 buckets and event notifications
│   ├── variables.tf            # Configurable variables
│   ├── iam.tf                  # IAM roles and policies
│   ├── lambda.tf               # Lambda function and API Gateway
│   └── outputs.tf              # Output values
│
├── lambda/                     # Backend Logic
│   └── handler.py              # Lambda function — all API logic
│
├── web/                        # Frontend
│   ├── index.html              # Main HTML with all tabs
│   ├── style.css               # Professional dark theme styling
│   └── app.js                  # All frontend JavaScript logic
│
├── test-images/                # Sample images for testing
├── .gitignore                  # Excludes sensitive and large files
└── README.md                   # This file


## ✅ Prerequisites

Before deploying this project ensure the following are installed:

| Tool | Version | Purpose |
|---|---|---|
| AWS CLI | v2+ | Interacting with AWS services |
| Terraform | v5.0+ | Infrastructure provisioning |
| Python | 3.10+ | Lambda runtime |
| Git | Any | Version control |

You also need an AWS account with access to Rekognition, S3, Lambda, API Gateway, IAM, and CloudWatch.

## 🚀 Deployment Guide

### Step 1 — Clone the Repository
git clone https://github.com/aplus19/aplus19-Rekognition-project.git
cd aplus19-Rekognition-project

### Step 2 — Configure AWS Credentials
aws configure
Enter your Access Key ID, Secret Access Key, and set default region to us-east-1.
Verify your identity:
aws sts get-caller-identity

### Step 3 — Deploy Infrastructure with Terraform
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
Terraform will create all AWS resources: S3 buckets, Lambda function, API Gateway, IAM roles, and CloudWatch logs.

### Step 4 — Note the Output Values
After Terraform completes it prints:
api_gateway_url         = "https://xxxxxxxx.execute-api.us-east-1.amazonaws.com"
image_inputs_bucket     = "project2-rekognition-image-inputs"
analysis_outputs_bucket = "project2-rekognition-analysis-outputs"
web_frontend_url        = "http://project2-rekognition-web-frontend.s3-website-us-east-1.amazonaws.com"
lambda_function_name    = "project2-rekognition-handler"

### Step 5 — Update Frontend API URL
Open web/app.js and update line 2:
API_URL: "https://xxxxxxxx.execute-api.us-east-1.amazonaws.com"

### Step 6 — Upload Frontend to S3
aws s3 sync ../web/ s3://project2-rekognition-web-frontend/ --delete

### Step 7 — Open Website
Copy the web_frontend_url from Step 4 and open in your browser! 🎉

## 🧪 Testing
### Test 1 — Image Analysis via S3 Upload
# Upload any JPEG or PNG image
aws s3 cp test-images/sample.jpg s3://project2-rekognition-image-inputs/uploads/

# Check results after 5 seconds
aws s3 ls s3://project2-rekognition-analysis-outputs/ --recursive

### Test 2 — Lambda Manual Test (AWS Console)
Go to **Lambda → project2-rekognition-handler → Test** and use:
{
  "bucket": "project2-rekognition-image-inputs",
  "key": "uploads/sample.jpg"
}

### Test 3 — API Direct Test
curl -X POST https://YOUR_API_URL/analyze \
  -H "Content-Type: application/json" \
  -d '{"action":"presign","key":"uploads/test.jpg"}

### Test 4 — ScanSafe Product Scan
- Go to the **🛡️ ScanSafe** tab on the website
- Upload a clear close-up photo of any product label
- Click **Scan Product**
- Results appear instantly with safety score

## 📊 Output Format
### Image Analysis JSON
  "metadata": {
    "source_key": "uploads/forest.jpg",
    "analyzed_at": "2026-03-22T14:00:00Z",
    "min_confidence": 70
  },
  "labels": [
    { "name": "Forest", "confidence": 99.1 },
    { "name": "Tree", "confidence": 98.7 }
  ],
  "faces": [
    {
      "face_index": 1,
      "age_range": { "low": 25, "high": 35 },
      "gender": { "value": "Male", "confidence": 98.5 },
      "emotions": [{ "type": "HAPPY", "confidence": 94.2 }],
      "smile": { "value": true, "confidence": 96.1 }
    }
  ],
  "text": [
    { "detected_text": "STOP", "confidence": 99.9 }
  ]
}

### ScanSafe Product Scan JSON
{
  "product_info": { "category": "Medicine/Drug" },
  "expiry": {
    "status": "VALID",
    "message": "Valid for 245 more days",
    "expiry_date": "2026-12-01"
  },
  "approval": {
    "status": "APPROVED",
    "message": "Approval markings found on label",
    "approval_numbers": ["FDA GH 1234"]
  },
  "ingredients": {
    "status": "SAFE",
    "message": "No dangerous ingredients detected",
    "banned_found": [],
    "allergens_found": []
  },
  "overall_safety": {
    "score": 95,
    "rating": "SAFE ✅",
    "issues": []
  }
}

## ⚠️ Error Handling

| Error | How It Is Handled |
|---|---|
| Unsupported image format | Returns 400 — "Please use JPEG or PNG" |
| File exceeds 5MB | Returns 400 — "File too large. Max 5MB" |
| No text found on label | Returns NOT_FOUND for expiry and approval |
| Rekognition API error | Logged to CloudWatch, returns error message |
| Unhandled exception | Logged with full context, returns 500 |

## 📈 Monitoring
### CloudWatch Logs
Lambda logs to CloudWatch automatically:
/aws/lambda/project2-rekognition-handler
View recent logs:
aws logs tail /aws/lambda/project2-rekognition-handler --follow

## 🌍 Real World Applications
- 🏥 **Healthcare** — Detect fake medicines and expired drugs
- 🌾 **Agriculture** — Crop disease detection for farmers  
- 🔐 **Security** — Face detection and identity verification
- 🏪 **Retail** — Auto-tag and categorize products
- 📄 **Document Processing** — OCR for digitizing records
- 🛡️ **Consumer Safety** — Detect banned ingredients in cosmetics and food

## 💰 AWS Free Tier
| Service | Free Tier | Sufficient For |
| Amazon Rekognition | 5,000 images/month | ✅ Classroom use |
| AWS Lambda | 1M requests/month | ✅ Classroom use |
| Amazon S3 | 5GB storage | ✅ Classroom use |
| API Gateway | 1M calls/month | ✅ Classroom use |
| CloudWatch | 10 metrics free | ✅ Classroom use |

**Estimated monthly cost for classroom use: $0.00** 🎉
## 🧹 Cleanup
To delete all AWS resources and avoid charges:
cd terraform
terraform destroy -auto-approve
This removes all S3 buckets, Lambda functions, API Gateway, IAM roles, and CloudWatch resources.

## 👨‍💻 Authors

**ANNOR MICHAEL OWUSUS** — Cloud & AI Engineering Student
**Group 4 Project** — Built as part of Cloud Computing coursework at Get Skill Network

## 📄 License
This project is licensed under the MIT License.

## 🙏 Acknowledgements
- [Amazon Rekognition Documentation](https://docs.aws.amazon.com/rekognition/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)
- [AWS Lambda Python Guide](https://docs.aws.amazon.com/lambda/latest/dg/python-handler.html)
- [Boto3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)
- [FDA Ghana](https://www.fdaghana.gov.gh/)

