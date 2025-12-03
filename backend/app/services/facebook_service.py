import requests
from typing import List, Dict, Any
from fastapi import HTTPException, status
import logging
from app.models.models import Reel, Comment
from app.metrics import fb_api_calls, label_for


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
        # Validate minimal configuration to avoid passing empty values to Graph API
        if not access_token:
            logging.warning("FacebookService initialized without access_token")
        if not page_id:
            logging.warning("FacebookService initialized without page_id")

        self.access_token = access_token or ""
        self.page_id = page_id or ""
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

    def _raise_http_error(self, e: requests.HTTPError, message: str):
        """Surface the underlying Facebook error payload to clients for debugging."""
        status_code = e.response.status_code if e.response is not None else 502
        body: Any
        try:
            body = e.response.json() if e.response is not None else None
        except Exception:
            body = e.response.text if e.response is not None else str(e)
        raise HTTPException(
            status_code=status_code,
            detail={"message": message, "facebook_error": body},
        )

    def get_user_info(self) -> Dict[str, Any]:
        url = f"{self.base_url}/{self.page_id}"
        params = self._build_params(
            {"fields": "id,name,picture"},
        )
        try:
            # metrics
            try:
                fb_api_calls.labels(method='get_user_info', page_id=label_for(self.page_id)).inc()
            except Exception:
                pass
            response = requests.get(url, params=params)
            response.raise_for_status()
            return response.json()
        except requests.HTTPError as e:
            self._raise_http_error(e, "Failed to fetch user/page info from Facebook")
        except Exception as e:
            # Network or other unexpected error
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(e))

    def get_reels(self) -> List[Reel]:
        url = f"{self.base_url}/{self.page_id}/video_reels"
        params = self._build_params(
            {
                "fields": "id,description,updated_time",
                "limit": self.reels_limit,
            }
        )
        try:
            # metrics
            try:
                fb_api_calls.labels(method='get_reels', page_id=label_for(self.page_id)).inc()
            except Exception:
                pass
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            return [Reel.parse_obj(item) for item in data.get("data", [])]
        except requests.HTTPError as e:
            self._raise_http_error(e, "Failed to fetch reels from Facebook")
        except Exception as e:
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(e))

    def get_posts(self) -> List[Dict[str, Any]]:
        url = f"{self.base_url}/{self.page_id}/posts"
        params = self._build_params(
            {
                "fields": "id,message,updated_time",
                "limit": 25,
            }
        )
        try:
            # metrics
            try:
                fb_api_calls.labels(method='get_posts', page_id=label_for(self.page_id)).inc()
            except Exception:
                pass
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            return data.get("data", [])
        except requests.HTTPError as e:
            self._raise_http_error(e, "Failed to fetch posts from Facebook")
        except Exception as e:
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(e))

    def get_comments(self, reel_id: str) -> List[Comment]:
        url = f"{self.base_url}/{reel_id}/comments"
        params = self._build_params(
            {
                "fields": self._build_comment_fields(),
                "limit": self.comments_limit,
            }
        )
        try:
            # metrics
            try:
                fb_api_calls.labels(method='get_comments', page_id=label_for(self.page_id)).inc()
            except Exception:
                pass
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            comments: List[Comment] = []
            for item in data.get("data", []):
                replies_edge = item.get("comments")
                replies: List[Dict[str, Any]] = []
                if isinstance(replies_edge, dict):
                    replies = replies_edge.get("data", []) or []
                    item["replies"] = replies

                    summary = replies_edge.get("summary") or {}
                    reply_count = summary.get("total_count")
                    if reply_count is not None:
                        item["reply_count"] = reply_count

                    if replies and any(
                        (reply.get("from") or {}).get("id") == self.page_id
                        for reply in replies
                    ):
                        item["has_replied"] = True

                    # Drop original Graph edge to avoid confusion during parsing
                    item.pop("comments", None)

                comments.append(Comment.parse_obj(item))

            return comments
        except requests.HTTPError as e:
            self._raise_http_error(e, "Failed to fetch comments from Facebook")
        except Exception as e:
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(e))

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
        try:
            # metrics
            try:
                fb_api_calls.labels(method='has_replied_to_comment', page_id=label_for(self.page_id)).inc()
            except Exception:
                pass
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()

            for reply in data.get("data", []):
                from_data = reply.get("from") or {}
                if from_data.get("id") == self.page_id:
                    return True
            return False
        except requests.HTTPError:
            # On error, assume not replied and allow caller to continue
            return False
        except Exception:
            return False

    def reply_to_comment(self, comment_id: str, message: str) -> Dict[str, Any]:
        url = f"{self.base_url}/{comment_id}/comments"
        params = self._build_params({"message": message})
        try:
            # metrics
            try:
                fb_api_calls.labels(method='reply_to_comment', page_id=label_for(self.page_id)).inc()
            except Exception:
                pass
            response = requests.post(url, params=params)
            response.raise_for_status()
            return response.json()
        except requests.HTTPError as e:
            raise HTTPException(status_code=e.response.status_code if e.response is not None else 502, detail="Failed to post reply to Facebook")
        except Exception as e:
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(e))

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
        try:
            # metrics
            try:
                fb_api_calls.labels(method='send_private_reply', page_id=label_for(self.page_id)).inc()
            except Exception:
                pass
            response = requests.post(url, params=params, json=payload, headers=headers)
            response.raise_for_status()
            return response.json()
        except requests.HTTPError as e:
            # Log full error body to help diagnose Graph API issues
            error_body = None
            try:
                if e.response is not None:
                    error_body = e.response.json()
                else:
                    error_body = {"raw": str(e)}
            except Exception:
                try:
                    error_body = {"raw": e.response.text if e.response is not None else str(e)}
                except Exception:
                    error_body = {"raw": str(e)}

            logging.error("Facebook private reply error: %s", error_body)

            # If Facebook reports that the activity is already replied to,
            # treat it as a non-fatal "duplicate" and do not raise.
            try:
                error_info = error_body.get("error") if isinstance(error_body, dict) else {}
                if error_info and error_info.get("code") == 10900:
                    # (#10900) Activity already replied to
                    return {}
            except Exception:
                pass

            raise HTTPException(status_code=502, detail={"facebook_error": error_body})
        except Exception as e:
            logging.exception("Unexpected error in send_private_reply")
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(e))

    def test_connection(self) -> bool:
        try:
            self.get_user_info()
            return True
        except Exception:
            return False
