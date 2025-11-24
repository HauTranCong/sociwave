import requests
from typing import List, Dict, Any
from app.models.models import Reel, Comment

class FacebookService:
    def __init__(self, access_token: str, page_id: str):
        self.access_token = access_token
        self.page_id = page_id
        self.base_url = "https://graph.facebook.com/v18.0"

    def get_user_info(self) -> Dict[str, Any]:
        url = f"{self.base_url}/{self.page_id}"
        params = {
            "access_token": self.access_token,
            "fields": "id,name,picture",
        }
        response = requests.get(url, params=params)
        response.raise_for_status()
        return response.json()

    def get_reels(self) -> List[Reel]:
        url = f"{self.base_url}/{self.page_id}/video_reels"
        params = {
            "access_token": self.access_token,
            "fields": "id,description,updated_time",
        }
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        return [Reel.parse_obj(item) for item in data.get("data", [])]

    def get_posts(self) -> List[Dict[str, Any]]:
        url = f"{self.base_url}/{self.page_id}/posts"
        params = {
            "access_token": self.access_token,
            "fields": "id,message,created_time",
        }
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        return data.get("data", [])

    def get_comments(self, reel_id: str) -> List[Comment]:
        url = f"{self.base_url}/{reel_id}/comments"
        params = {
            "access_token": self.access_token,
            "fields": "id,message,from,created_time,updated_time,comments{id,message,from,created_time,updated_time}",
        }
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        return [Comment.parse_obj(item) for item in data.get("data", [])]

    def reply_to_comment(self, comment_id: str, message: str) -> Dict[str, Any]:
        url = f"{self.base_url}/{comment_id}/comments"
        params = {
            "access_token": self.access_token,
            "message": message,
        }
        response = requests.post(url, params=params)
        response.raise_for_status()
        return response.json()

    def send_private_reply(self, comment_id: str, message: str) -> Dict[str, Any]:
        url = f"{self.base_url}/{comment_id}/private_replies"
        params = {
            "access_token": self.access_token,
            "message": message,
        }
        response = requests.post(url, params=params)
        response.raise_for_status()
        return response.json()

    def test_connection(self) -> bool:
        try:
            self.get_user_info()
            return True
        except Exception:
            return False
