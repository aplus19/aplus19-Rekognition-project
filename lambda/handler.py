
import json
import boto3
import os
import logging
import base64
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

rekognition = boto3.client("rekognition")
s3 = boto3.client("s3")

OUTPUT_BUCKET = os.environ["OUTPUT_BUCKET"]
INPUT_BUCKET = os.environ["INPUT_BUCKET"]
MIN_CONFIDENCE = float(os.environ.get("MIN_CONFIDENCE", "70"))


def lambda_handler(event, context):
    logger.info("Event: %s", json.dumps(event))
    if "Records" in event:
        return handle_s3_event(event)
    if "requestContext" in event:
        return handle_api_event(event)
    bucket = event.get("bucket")
    key = event.get("key")
    if bucket and key:
        result = analyze_image(bucket, key)
        return {"statusCode": 200, "body": json.dumps(result, indent=2)}
    return {"statusCode": 400, "body": "Unknown event format"}


def handle_s3_event(event):
    results = []
    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]
        logger.info("S3 trigger: s3://%s/%s", bucket, key)
        result = analyze_image(bucket, key)
        results.append(result)
    return results


def handle_api_event(event):
    if "requestContext" in event and "http" in event.get("requestContext", {}):
        method = event["requestContext"]["http"]["method"]
    elif "httpMethod" in event:
        method = event["httpMethod"]
    else:
        method = "POST"

    body = {}
    if event.get("body"):
        try:
            body = json.loads(event["body"])
        except Exception:
            body = {}

    action = body.get("action", "analyze")
    logger.info("Action: %s", action)

    if action == "presign":
        key = body.get("key")
        if not key:
            return api_response(400, {"error": "Missing key"})
        try:
            url = generate_presigned_url(key)
            return api_response(200, {"upload_url": url, "key": key})
        except Exception as e:
            logger.error("Presign error: %s", str(e))
            return api_response(500, {"error": str(e)})

    if action == "analyze_base64":
        image_data = body.get("image_data")
        filename = body.get("filename", "image.jpg")
        if not image_data:
            return api_response(400, {"error": "Missing image_data"})
        try:
            image_bytes = base64.b64decode(image_data)
            result = analyze_image_bytes(image_bytes, filename)
            return api_response(200, result)
        except Exception as e:
            logger.error("Base64 analysis error: %s", str(e))
            return api_response(500, {"error": str(e)})

    if action == "fetch_latest":
        image_name = body.get("image_name")
        if not image_name:
            return api_response(400, {"error": "Missing image_name"})
        return fetch_latest_result(image_name)

    key = body.get("key")
    if not key:
        return api_response(400, {"error": "Missing key"})
    bucket = body.get("bucket", INPUT_BUCKET)
    result = analyze_image(bucket, key)
    return api_response(200, result)


def analyze_image(bucket, key):
    timestamp = datetime.now(timezone.utc).isoformat()
    image_name = key.split("/")[-1].rsplit(".", 1)[0]
    logger.info("Analyzing: s3://%s/%s", bucket, key)
    result = {
        "metadata": {
            "source_bucket": bucket,
            "source_key": key,
            "image_name": image_name,
            "analyzed_at": timestamp,
            "min_confidence": MIN_CONFIDENCE
        },
        "labels": detect_labels({"S3Object": {"Bucket": bucket, "Name": key}}),
        "faces": detect_faces({"S3Object": {"Bucket": bucket, "Name": key}}),
        "text": detect_text({"S3Object": {"Bucket": bucket, "Name": key}})
    }
    output_key = image_name + "/" + timestamp + "_analysis.json"
    save_result(result, output_key)
    result["output_key"] = output_key
    logger.info("Saved to: s3://%s/%s", OUTPUT_BUCKET, output_key)
    return result


def analyze_image_bytes(image_bytes, filename):
    timestamp = datetime.now(timezone.utc).isoformat()
    image_name = filename.rsplit(".", 1)[0]
    image_obj = {"Bytes": image_bytes}
    result = {
        "metadata": {
            "image_name": image_name,
            "analyzed_at": timestamp,
            "min_confidence": MIN_CONFIDENCE
        },
        "labels": detect_labels(image_obj),
        "faces": detect_faces(image_obj),
        "text": detect_text(image_obj)
    }
    output_key = image_name + "/" + timestamp + "_analysis.json"
    save_result(result, output_key)
    result["output_key"] = output_key
    return result


def detect_labels(image_obj):
    try:
        response = rekognition.detect_labels(
            Image=image_obj,
            MaxLabels=20,
            MinConfidence=MIN_CONFIDENCE
        )
        return [
            {
                "name": l["Name"],
                "confidence": round(l["Confidence"], 2),
                "categories": [c["Name"] for c in l.get("Categories", [])],
                "parents": [p["Name"] for p in l.get("Parents", [])]
            }
            for l in response["Labels"]
        ]
    except Exception as e:
        logger.error("DetectLabels error: %s", str(e))
        return [{"error": str(e)}]


def detect_faces(image_obj):
    try:
        response = rekognition.detect_faces(
            Image=image_obj,
            Attributes=["ALL"]
        )
        faces = []
        for i, face in enumerate(response["FaceDetails"]):
            top_emotions = sorted(
                face.get("Emotions", []),
                key=lambda e: e["Confidence"],
                reverse=True
            )[:3]
            faces.append({
                "face_index": i + 1,
                "confidence": round(face["Confidence"], 2),
                "age_range": {
                    "low": face["AgeRange"]["Low"],
                    "high": face["AgeRange"]["High"]
                },
                "gender": {
                    "value": face["Gender"]["Value"],
                    "confidence": round(face["Gender"]["Confidence"], 2)
                },
                "emotions": [
                    {"type": e["Type"], "confidence": round(e["Confidence"], 2)}
                    for e in top_emotions
                ],
                "smile": {
                    "value": face["Smile"]["Value"],
                    "confidence": round(face["Smile"]["Confidence"], 2)
                },
                "eyeglasses": {
                    "value": face["Eyeglasses"]["Value"],
                    "confidence": round(face["Eyeglasses"]["Confidence"], 2)
                },
                "bounding_box": face["BoundingBox"]
            })
        return faces
    except Exception as e:
        logger.error("DetectFaces error: %s", str(e))
        return [{"error": str(e)}]


def detect_text(image_obj):
    try:
        response = rekognition.detect_text(Image=image_obj)
        return [
            {
                "detected_text": item["DetectedText"],
                "type": item["Type"],
                "confidence": round(item["Confidence"], 2)
            }
            for item in response["TextDetections"]
            if item["Confidence"] >= MIN_CONFIDENCE
        ]
    except Exception as e:
        logger.error("DetectText error: %s", str(e))
        return [{"error": str(e)}]


def save_result(result, output_key):
    s3.put_object(
        Bucket=OUTPUT_BUCKET,
        Key=output_key,
        Body=json.dumps(result, indent=2),
        ContentType="application/json"
    )


def get_result(result_key):
    try:
        obj = s3.get_object(Bucket=OUTPUT_BUCKET, Key=result_key)
        body = obj["Body"].read().decode("utf-8")
        return api_response(200, json.loads(body))
    except Exception as e:
        return api_response(500, {"error": str(e)})


def fetch_latest_result(image_name):
    try:
        response = s3.list_objects_v2(
            Bucket=OUTPUT_BUCKET,
            Prefix=image_name + "/"
        )
        if "Contents" not in response:
            return api_response(404, {"error": "No results yet"})
        latest = sorted(
            response["Contents"],
            key=lambda x: x["LastModified"],
            reverse=True
        )[0]
        return get_result(latest["Key"])
    except Exception as e:
        return api_response(500, {"error": str(e)})


def generate_presigned_url(key):
    return s3.generate_presigned_url(
        "put_object",
        Params={"Bucket": INPUT_BUCKET, "Key": key},
        ExpiresIn=300
    )


def api_response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body)
    }


