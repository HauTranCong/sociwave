import requests
from typing import List, Dict, Any
from app.models.models import Reel, Comment


class FacebookService:
    """
    Server-side Facebook Graph API client.

    This mirrors the behavior of the Flutter `FacebookApiService` so that
    the backend and frontend use the same fields, limits, and reply behavior.
    """

    def __init__(
        self,
        access_token: str,
        page_id: str,
        version: str = "v18.0",
        reels_limit: int = 25,
        comments_limit: int = 100,
        replies_limit: int = 100,
    ):
        self.access_token = access_token
        self.page_id = page_id
        self.version = version
        self.base_url = f"https://graph.facebook.com/{self.version}"
        self.reels_limit = reels_limit
        self.comments_limit = comments_limit
        self.replies_limit = replies_limit

    def _build_params(self, extra: Dict[str, Any] | None = None) -> Dict[str, Any]:
        params: Dict[str, Any] = {"access_token": self.access_token}
        if extra:
            params.update(extra)
        return params

    def _build_comment_fields(self) -> str:
        # Match Flutter's _buildCommentFields:
        # 'id,message,from,created_time,updated_time,comments.limit(N).summary(true){id,message,from,created_time}'
        return (
            "id,message,from,created_time,updated_time,"
            f"comments.limit({self.replies_limit}).summary(true)"
            "{id,message,from,created_time}"
        )

    def get_user_info(self) -> Dict[str, Any]:
        url = f"{self.base_url}/{self.page_id}"
        params = self._build_params(
            {"fields": "id,name,picture"},
        )
        response = requests.get(url, params=params)
        response.raise_for_status()
        return response.json()

    def get_reels(self) -> List[Reel]:
        url = f"{self.base_url}/{self.page_id}/video_reels"
        params = self._build_params(
            {
                "fields": "id,description,updated_time",
                "limit": self.reels_limit,
            }
        )
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        return [Reel.parse_obj(item) for item in data.get("data", [])]

    def get_posts(self) -> List[Dict[str, Any]]:
        url = f"{self.base_url}/{self.page_id}/posts"
        params = self._build_params(
            {
                "fields": "id,message,updated_time",
                "limit": 25,
            }
        )
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        return data.get("data", [])

    def get_comments(self, reel_id: str) -> List[Comment]:
        url = f"{self.base_url}/{reel_id}/comments"
        params = self._build_params(
            {
                "fields": self._build_comment_fields(),
                "limit": self.comments_limit,
            }
        )
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        return [Comment.parse_obj(item) for item in data.get("data", [])]

    def has_replied_to_comment(self, comment_id: str) -> bool:
        """
        Check, for a specific user comment, whether the page has already
        replied in that comment's thread.
        """
        url = f"{self.base_url}/{comment_id}/comments"
        params = self._build_params(
            {
                "fields": "id,from",
                "limit": 100,
            }
        )
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()

        for reply in data.get("data", []):
            from_data = reply.get("from") or {}
            if from_data.get("id") == self.page_id:
                return True
        return False

    def reply_to_comment(self, comment_id: str, message: str) -> Dict[str, Any]:
        url = f"{self.base_url}/{comment_id}/comments"
        params = self._build_params({"message": message})
        response = requests.post(url, params=params)
        response.raise_for_status()
        return response.json()

    def send_private_reply(self, comment_id: str, message: str) -> Dict[str, Any]:
        """
        Use the Private Replies API via page messages endpoint, mirroring
        Flutter's sendPrivateReply (uses comment_id in recipient).
        """
        url = f"{self.base_url}/{self.page_id}/messages"
        params = self._build_params()
        payload = {
            "recipient": {"comment_id": comment_id},
            "message": {"text": message},
        }
        headers = {"Content-Type": "application/json"}
        response = requests.post(url, params=params, json=payload, headers=headers)
        try:
            response.raise_for_status()
        except requests.HTTPError:
            # Log full error body to help diagnose Graph API issues
            try:
                error_body = response.json()
            except Exception:
                error_body = {"raw": response.text}

            print("Facebook private reply error:", error_body)

            # If Facebook reports that the activity is already replied to,
            # treat it as a non-fatal "duplicate" and do not raise.
            try:
                error_info = error_body.get("error") or {}
                if error_info.get("code") == 10900:
                    # (#10900) Activity already replied to
                    return {}
            except Exception:
                pass

            # For all other errors, propagate the exception
            raise

        return response.json()

    def test_connection(self) -> bool:
        try:
            self.get_user_info()
            return True
        except Exception:
            return False
