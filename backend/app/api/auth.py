from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordRequestForm
import logging
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.services.auth_service import AuthService, Token, SECRET_KEY, ALGORITHM
from app.models.models import UserModel
from jose import JWTError, jwt

router = APIRouter()

logger = logging.getLogger(__name__)


def _get_token_from_request(request: Request):
    """Extract token from Authorization header and log presence/absence for debugging.

    This avoids logging the token contents; we only log whether the header existed.
    """
    auth = request.headers.get('authorization')
    if not auth:
        logger.info('Auth header missing on request to %s', request.url.path)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Not authenticated')

    # Expect "Bearer <token>"; return token part if present
    if auth.lower().startswith('bearer '):
        return auth[7:]
    return auth

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_auth_service(db: Session = Depends(get_db)):
    return AuthService(db)

@router.post("/token", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), auth_service: AuthService = Depends(get_auth_service)):
    user = auth_service.authenticate_user(form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token = auth_service.create_access_token(
        data={"sub": user.username}
    )
    return {"access_token": access_token, "token_type": "bearer", "theme_mode": user.theme_mode}

def get_current_user(request: Request, auth_service: AuthService = Depends(get_auth_service)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        token = _get_token_from_request(request)
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        except JWTError as e:
            logger.info('JWT decode failed for request to %s: %s', request.url.path, str(e))
            raise credentials_exception
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    user = auth_service.get_user(username)
    if user is None:
        raise credentials_exception
    return user

@router.put("/users/me/theme")
async def update_theme(theme_mode: str, current_user: UserModel = Depends(get_current_user), auth_service: AuthService = Depends(get_auth_service)):
    if theme_mode not in ['light', 'dark', 'system']:
        raise HTTPException(status_code=400, detail="Invalid theme mode")
    current_user.theme_mode = theme_mode
    auth_service.db.commit()
    return {"message": "Theme updated successfully"}
