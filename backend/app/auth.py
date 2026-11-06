import os
import bcrypt
from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr

from app.database import get_db
from app.models import User


# Configuración de JWT
SECRET_KEY = os.getenv("SECRET_KEY", "divivoice-super-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7 # 7 días de duración del token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login-oauth")

router = APIRouter(prefix="/api/auth", tags=["auth"])

# Pydantic Schemas
class UserRegister(BaseModel):
    username: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    email_or_username: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str
    user: Optional['UserOut'] = None

class UserOut(BaseModel):
    id: int
    username: str
    email: str
    avatar_url: str
    bio: str
    coins: int = 500
    gems: int = 0
    created_at: datetime

    class Config:
        from_attributes = True

Token.update_forward_refs()

# Helper functions
def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    except Exception:
        return False

def get_password_hash(password: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# Obtener usuario actual desde el Token JWT
def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Credenciales de autenticación no válidas.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        sub = payload.get("sub")
        if sub is None:
            raise credentials_exception
        user_id = int(sub)
    except (JWTError, ValueError):
        raise credentials_exception
        
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise credentials_exception
    return user

# Endpoints
@router.post("/register", response_model=Token)
def register(user_in: UserRegister, db: Session = Depends(get_db)):
    # Validar si ya existe el correo o nombre de usuario
    db_user_email = db.query(User).filter(User.email == user_in.email).first()
    if db_user_email:
        raise HTTPException(
            status_code=400,
            detail="El correo electrónico ya está registrado."
        )
    db_user_username = db.query(User).filter(User.username == user_in.username).first()
    if db_user_username:
        raise HTTPException(
            status_code=400,
            detail="El nombre de usuario ya está tomado."
        )
        
    # Crear nuevo usuario
    hashed_pw = get_password_hash(user_in.password)
    new_user = User(
        username=user_in.username,
        email=user_in.email,
        hashed_password=hashed_pw,
        coins=500,
        gems=0
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    access_token = create_access_token(
        data={"sub": str(new_user.id)},
        expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": UserOut.from_orm(new_user)
    }

@router.post("/login", response_model=Token)
def login(login_in: UserLogin, db: Session = Depends(get_db)):
    # Buscar por email o username
    user = db.query(User).filter(
        (User.email == login_in.email_or_username) | 
        (User.username == login_in.email_or_username)
    ).first()
    
    if not user or not verify_password(login_in.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales incorrectas (usuario/correo o contraseña)."
        )
        
    access_token = create_access_token(
        data={"sub": str(user.id)},
        expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": UserOut.from_orm(user)
    }

@router.post("/quick-login/{username}", response_model=Token)
def quick_login(username: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(
        (User.username == username) | (User.email == username)
    ).first()
    if not user:
        # Si no existe, crear usuario rápidamente
        hashed_pw = get_password_hash("divivoice123")
        user = User(
            username=username,
            email=f"{username.lower()}@divivoice.com",
            hashed_password=hashed_pw,
            coins=2100,
            gems=100
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    access_token = create_access_token(
        data={"sub": str(user.id)},
        expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": UserOut.from_orm(user)
    }

# Endpoint para compatibilidad con el OAuth2PasswordBearer en documentación Swagger/FastAPI
from fastapi.security import OAuth2PasswordRequestForm
@router.post("/login-oauth", response_model=Token, include_in_schema=False)
def login_oauth(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(
        (User.email == form_data.username) | 
        (User.username == form_data.username)
    ).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales incorrectas."
        )
    access_token = create_access_token(
        data={"sub": str(user.id)},
        expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    return {"access_token": access_token, "token_type": "bearer"}

@router.get("/me", response_model=UserOut)
def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user

class ProfileUpdate(BaseModel):
    username: Optional[str] = None
    bio: Optional[str] = None

@router.put("/profile", response_model=UserOut)
def update_profile(
    profile_in: ProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if profile_in.username and profile_in.username != current_user.username:
        existing = db.query(User).filter(User.username == profile_in.username).first()
        if existing and existing.id != current_user.id:
            raise HTTPException(status_code=400, detail="El nombre de usuario ya está tomado.")
        current_user.username = profile_in.username

    if profile_in.bio is not None:
        current_user.bio = profile_in.bio

    db.commit()
    db.refresh(current_user)
    return current_user

from fastapi import File, UploadFile
import shutil
from pathlib import Path
from app.config import OUTPUT_DIR

@router.post("/avatar", response_model=UserOut)
async def upload_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ext = file.filename.split('.')[-1].lower() if '.' in file.filename else 'jpg'
    if ext not in ['jpg', 'jpeg', 'png', 'webp']:
        raise HTTPException(status_code=400, detail="Formato de imagen no soportado (usa JPG, PNG o WebP).")

    media_dir = OUTPUT_DIR / "avatars"
    os.makedirs(media_dir, exist_ok=True)
    filename = f"avatar_user_{current_user.id}_{int(datetime.utcnow().timestamp())}.{ext}"
    dest_path = media_dir / filename

    with open(dest_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    current_user.avatar_url = f"/media/avatars/{filename}"
    db.commit()
    db.refresh(current_user)
    return current_user


