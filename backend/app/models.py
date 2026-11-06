import datetime
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Table
from sqlalchemy.orm import relationship
from app.database import Base

# Tabla de asociación para Seguidos/Seguidores
followers = Table(
    "followers",
    Base.metadata,
    Column("follower_id", Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
    Column("followed_id", Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
)

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    avatar_url = Column(String, default="/logo/logo.jpg")
    bio = Column(String, default="")
    coins = Column(Integer, default=500)
    gems = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    # Relaciones
    covers = relationship("Cover", back_populates="user", cascade="all, delete-orphan")
    comments = relationship("Comment", back_populates="user", cascade="all, delete-orphan")
    likes = relationship("Like", back_populates="user", cascade="all, delete-orphan")
    stories = relationship("Story", back_populates="user", cascade="all, delete-orphan")
    
    # Muchos a muchos para seguidores
    following = relationship(
        "User",
        secondary=followers,
        primaryjoin=id == followers.c.follower_id,
        secondaryjoin=id == followers.c.followed_id,
        backref="followers"
    )

class Cover(Base):
    __tablename__ = "covers"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(String, default="")
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    instrumental_path = Column(String, nullable=True)
    vocal_path = Column(String, nullable=True)
    mix_path = Column(String, nullable=True)
    video_path = Column(String, nullable=True)
    lyrics_path = Column(String, nullable=True)
    duration = Column(Integer, default=0) # en segundos
    likes_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    # Relaciones
    user = relationship("User", back_populates="covers")
    comments = relationship("Comment", back_populates="cover", cascade="all, delete-orphan")
    likes_rel = relationship("Like", back_populates="cover", cascade="all, delete-orphan")

class Like(Base):
    __tablename__ = "likes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    cover_id = Column(Integer, ForeignKey("covers.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="likes")
    cover = relationship("Cover", back_populates="likes_rel")

class Comment(Base):
    __tablename__ = "comments"

    id = Column(Integer, primary_key=True, index=True)
    content = Column(String, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    cover_id = Column(Integer, ForeignKey("covers.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="comments")
    cover = relationship("Cover", back_populates="comments")

class Room(Base):
    __tablename__ = "rooms"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    host_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    is_active = Column(Boolean, default=True)
    active_singer_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    current_song_title = Column(String, nullable=True)
    current_song_job_id = Column(String, nullable=True) # Job ID del extractor de voz (FastAPI)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    host = relationship("User", foreign_keys=[host_id])
    active_singer = relationship("User", foreign_keys=[active_singer_id])
    seats = relationship("RoomSeat", back_populates="room", cascade="all, delete-orphan")
    queue = relationship("RoomQueue", back_populates="room", cascade="all, delete-orphan")

class RoomSeat(Base):
    __tablename__ = "room_seats"

    id = Column(Integer, primary_key=True, index=True)
    room_id = Column(Integer, ForeignKey("rooms.id", ondelete="CASCADE"), nullable=False)
    seat_index = Column(Integer, nullable=False) # 0 a 7 u 8
    user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    is_muted = Column(Boolean, default=False)

    room = relationship("Room", back_populates="seats")
    user = relationship("User")

class RoomQueue(Base):
    __tablename__ = "room_queues"

    id = Column(Integer, primary_key=True, index=True)
    room_id = Column(Integer, ForeignKey("rooms.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    song_title = Column(String, nullable=False)
    youtube_url = Column(String, nullable=True)
    job_id = Column(String, nullable=True) # ID del trabajo de separación
    status = Column(String, default="pending") # pending, singing, completed
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    room = relationship("Room", back_populates="queue")
    user = relationship("User")

class Story(Base):
    __tablename__ = "stories"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    media_url = Column(String, nullable=False)
    caption = Column(String, default="")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    expires_at = Column(DateTime, nullable=False)

    user = relationship("User", back_populates="stories")

class Gift(Base):
    __tablename__ = "gifts"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    icon = Column(String, nullable=False) # e.g. fa-solid fa-microphone-lines, or SVG
    price = Column(Integer, nullable=False) # costo en monedas
    animation = Column(String, default="pop") # pop, fire, crown, rain
    category = Column(String, default="popular") # popular, vip, concert

class GiftTransaction(Base):
    __tablename__ = "gift_transactions"

    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    receiver_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    room_id = Column(Integer, ForeignKey("rooms.id", ondelete="SET NULL"), nullable=True)
    cover_id = Column(Integer, ForeignKey("covers.id", ondelete="SET NULL"), nullable=True)
    gift_id = Column(Integer, ForeignKey("gifts.id", ondelete="CASCADE"), nullable=False)
    coins_amount = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    sender = relationship("User", foreign_keys=[sender_id])
    receiver = relationship("User", foreign_keys=[receiver_id])
    gift = relationship("Gift")
