import requests
import json
import concurrent.futures
import time

BASE_URL = "http://localhost:8000/api"

def print_response(name, response):
    """Helper to print formatted JSON responses."""
    print(f"--- {name} (Status: {response.status_code}) ---")
    try:
        print(json.dumps(response.json(), indent=2))
    except json.JSONDecodeError:
        print(response.text)
    print("-" * (len(name) + 20))
    print()

def test_login():
    """Authenticate and return the access token."""
    login_data = {"username": "testuser", "password": "testpassword"}
    response = requests.post(f"{BASE_URL}/auth/token", data=login_data)
    print_response("1. User Login", response)
    if response.status_code == 200:
        return response.json().get("access_token")
    return None

def get_config(headers):
    """Fetch the current configuration."""
    response = requests.get(f"{BASE_URL}/config", headers=headers)
    print_response("2. Get Initial Config", response)

def save_config(headers):
    """Save a new application configuration."""
    config_data = {
        "accessToken": "", # IMPORTANT: Replace with a valid token
        "pageId": "",           # IMPORTANT: Replace with a valid Page ID
        "version": "v20.0",
        "useMockData": False,
        "reelsLimit": 5,
        "commentsLimit": 20,
        "repliesLimit": 20,
    }
    response = requests.post(f"{BASE_URL}/config", json=config_data, headers=headers)
    print_response("3. Save New Config", response)

def get_rules(headers):
    """Fetch the current rules."""
    response = requests.get(f"{BASE_URL}/rules", headers=headers)
    print_response("4. Get Initial Rules", response)

def save_rules(headers):
    """Save a new set of rules."""
    rules_data = {
        "123456789012345": { # Example Reel ID 1
            "object_id": "123456789012345",
            "match_words": ["price", "cost", "how much"],
            "reply_message": "Thanks for asking! We've sent the details to your inbox.",
            "inbox_message": "Hello! The price for this item is $19.99. Let us know if you have more questions!",
            "enabled": True,
        },
        "678901234567890": { # Example Reel ID 2
            "object_id": "678901234567890",
            "match_words": ["available", "in stock"],
            "reply_message": "Yes, this is currently in stock! Check our website for more details.",
            "enabled": True,
        },
    }
    response = requests.post(f"{BASE_URL}/rules", json=rules_data, headers=headers)
    print_response("5. Save New Rules", response)

def trigger_monitoring(headers):
    """Trigger the main monitoring task."""
    print("--- 6. Triggering Monitoring Cycle ---")
    response = requests.post(f"{BASE_URL}/trigger-monitoring", headers=headers)
    print_response("Monitoring Cycle Response", response)
    print("-" * 40)

def stress_test_worker(auth_token, worker_id):
    """A single worker's task for the stress test."""
    print(f"[Worker {worker_id}] Starting task.")
    headers = {"Authorization": f"Bearer {auth_token}"}
    try:
        # Simulate a common user action: fetching data
        config_res = requests.get(f"{BASE_URL}/config", headers=headers, timeout=10)
        rules_res = requests.get(f"{BASE_URL}/rules", headers=headers, timeout=10)
        if config_res.status_code == 200 and rules_res.status_code == 200:
            print(f"[Worker {worker_id}] Task successful.")
            return True
        else:
            print(f"[Worker {worker_id}] Task failed: Config Status={config_res.status_code}, Rules Status={rules_res.status_code}")
            return False
    except requests.RequestException as e:
        print(f"[Worker {worker_id}] Task error: {e}")
        return False

def run_stress_test(auth_token, num_workers=10, max_requests=50):
    """Run a stress test with concurrent workers."""
    print("\n--- 7. Starting Stress Test ---")
    print(f"Simulating {max_requests} requests using {num_workers} concurrent workers.\n")
    
    start_time = time.time()
    success_count = 0
    failure_count = 0

    with concurrent.futures.ThreadPoolExecutor(max_workers=num_workers) as executor:
        futures = [executor.submit(stress_test_worker, auth_token, i) for i in range(max_requests)]
        
        for future in concurrent.futures.as_completed(futures):
            if future.result():
                success_count += 1
            else:
                failure_count += 1

    end_time = time.time()
    duration = end_time - start_time
    
    print("\n--- Stress Test Results ---")
    print(f"Total requests: {max_requests}")
    print(f"Successful requests: {success_count}")
    print(f"Failed requests: {failure_count}")
    print(f"Total duration: {duration:.2f} seconds")
    if duration > 0:
        print(f"Requests per second: {max_requests / duration:.2f}")
    print("-" * 28 + "\n")


def main():
    """Run the full test scenario."""
    access_token = test_login()
    if not access_token:
        print("Login failed. Exiting test.")
        return

    headers = {"Authorization": f"Bearer {access_token}"}

    # Run the sequential workflow
    get_config(headers)
    save_config(headers)
    get_rules(headers)
    save_rules(headers)
    trigger_monitoring(headers)

    # Run the stress test
    run_stress_test(access_token, num_workers=20, max_requests=100)


if __name__ == "__main__":
    main()