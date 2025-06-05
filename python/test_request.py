# file: python/test_request.py
import requests, json

url = "http://127.0.0.1:5000/predict"
payload = {
    "features": [
        0.1, 0.2, 0.3, 0.4, 0.5,   # 5
        1.0, 2.0, 3.0, 4.0, 5.0,   # 10
        6.0, 7.0, 8.0, 9.0, 10.0,  # 15
        11.0, 12.0, 13.0, 14.0, 15.0 # 20
    ]
}
headers = {"Content-Type": "application/json"}

response = requests.post(url, data=json.dumps(payload), headers=headers)
print("HTTP Status Code:", response.status_code)
print("Response JSON:")
print(response.text)
