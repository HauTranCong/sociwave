import requests
import json

BASE_URL = "http://localhost:8000/api"

def print_response(name, response):
    print(f"--- {name} ---")
    try:
        print(json.dumps(response.json(), indent=2))
    except json.JSONDecodeError:
        print(response.text)
    print("-" * (len(name) + 8))
    print()

def main():
    # 1. Configure the backend
    config_data = {
        "accessToken": "",
        "pageId": ""
    }
    response = requests.post(f"{BASE_URL}/config", json=config_data)
    print_response("Save Config", response)

    # 2. Test the connection
    response = requests.get(f"{BASE_URL}/test-connection")
    print_response("Test Connection", response)

    # 3. Fetch video reels
    response = requests.get(f"{BASE_URL}/reels")
    print_response("Get reels", response)

    # 4. Trigger monitoring
    response = requests.post(f"{BASE_URL}/trigger-monitoring")
    print_response("Trigger Monitoring", response)

if __name__ == "__main__":
    main()
