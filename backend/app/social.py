import os
import json
import uuid
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Form, UploadFile, File
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.database import get_db
from app.models import User, Cover, Like, Comment, Gift, Story, GiftTransaction
from app.auth import get_current_user, UserOut
from app.config import OUTPUT_DIR

router = APIRouter(prefix="/api/social", tags=["social"])

# Pydantic schemas
class CommentCreate(BaseModel):
    content: str

class CommentOut(BaseModel):
    id: int
    content: str
    created_at: datetime
    user: UserOut

    class Config:
        from_attributes = True

class CoverOut(BaseModel):
    id: int
    title: str
    description: str
    user: UserOut
    instrumental_path: Optional[str]
    vocal_path: Optional[str]
    mix_path: Optional[str]
    video_path: Optional[str]
    lyrics_path: Optional[str]
    duration: int
    likes_count: int
    has_liked: bool = False
    created_at: datetime

    class Config:
        from_attributes = True

class UserProfileOut(UserOut):
    following_count: int
    followers_count: int
    is_following: bool = False

DEFAULT_POPULAR_SONGS = [
    {
        "job_id": "demo_despacito",
        "title": "Despacito",
        "artist": "Luis Fonsi & Daddy Yankee",
        "genre": "Reggaetón / Pop Latino",
        "cover_image": "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300&auto=format&fit=crop&q=80",
        "duration": 228,
        "difficulty": "Media",
        "plays_count": "1.2M",
        "instrumental_url": "/media/demo_song_latino_inst.mp3",
        "lyrics_url": "/media/demo_song_latino_lyrics.json",
    },
    {
        "job_id": "demo_bohemian",
        "title": "Bohemian Rhapsody",
        "artist": "Queen",
        "genre": "Rock Clásico",
        "cover_image": "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300&auto=format&fit=crop&q=80",
        "duration": 354,
        "difficulty": "Alta",
        "plays_count": "950K",
        "instrumental_url": "/media/demo_song_latino_inst.mp3",
        "lyrics_url": "/media/demo_song_latino_lyrics.json",
    },
    {
        "job_id": "demo_provenza",
        "title": "Provenza",
        "artist": "Karol G",
        "genre": "Urbano / Pop",
        "cover_image": "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300&auto=format&fit=crop&q=80",
        "duration": 210,
        "difficulty": "Fácil",
        "plays_count": "1.8M",
        "instrumental_url": "/media/demo_song_latino_inst.mp3",
        "lyrics_url": "/media/demo_song_latino_lyrics.json",
    },
    {
        "job_id": "demo_besame",
        "title": "Bésame Mucho",
        "artist": "Luis Miguel",
        "genre": "Bolero / Romántico",
        "cover_image": "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300&auto=format&fit=crop&q=80",
        "duration": 245,
        "difficulty": "Media",
        "plays_count": "680K",
        "instrumental_url": "/media/demo_song_latino_inst.mp3",
        "lyrics_url": "/media/demo_song_latino_lyrics.json",
    },
    {
        "job_id": "demo_shapeofyou",
        "title": "Shape of You",
        "artist": "Ed Sheeran",
        "genre": "Pop Internacional",
        "cover_image": "https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=300&auto=format&fit=crop&q=80",
        "duration": 233,
        "difficulty": "Fácil",
        "plays_count": "2.4M",
        "instrumental_url": "/media/demo_song_latino_inst.mp3",
        "lyrics_url": "/media/demo_song_latino_lyrics.json",
    },
    {
        "job_id": "demo_laincondicional",
        "title": "La Incondicional",
        "artist": "Luis Miguel",
        "genre": "Balada Pop",
        "cover_image": "https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=300&auto=format&fit=crop&q=80",
        "duration": 259,
        "difficulty": "Alta",
        "plays_count": "890K",
        "instrumental_url": "/media/demo_song_latino_inst.mp3",
        "lyrics_url": "/media/demo_song_latino_lyrics.json",
    }
]

# Endpoints de Canciones (Catálogo extraído por IA en el backend)
@router.get("/songs")
def get_songs_catalog():
    """
    Lista las canciones disponibles para cantar (trabajos completados exitosamente
    por la IA con instrumental y letra generada, más canciones populares precargadas).
    """
    songs = list(DEFAULT_POPULAR_SONGS)
    if os.path.exists(OUTPUT_DIR):
        for filename in os.listdir(OUTPUT_DIR):
            if filename.endswith("_status.json"):
                job_id = filename.replace("_status.json", "")
                try:
                    with open(os.path.join(OUTPUT_DIR, filename), "r", encoding="utf-8") as f:
                        data = json.load(f)
                        
                    if data.get("status") == "completed":
                        # Buscar el archivo instrumental
                        instrumental = None
                        for out_f in data.get("files", []):
                            if "(Instrumental)" in out_f:
                                instrumental = f"/media/{out_f}"
                                break
                                
                        songs.insert(0, {
                            "job_id": job_id,
                            "title": data.get("original_filename", "Canción Importada").replace(".mp3", "").replace(".wav", ""),
                            "artist": "IA Separator Studio",
                            "genre": "Karaoke Separado por IA",
                            "cover_image": "/logo/logo.jpg",
                            "duration": 180,
                            "difficulty": "Personalizada",
                            "plays_count": "Nuevo",
                            "instrumental_url": instrumental,
                            "lyrics_url": f"/media/{data.get('lyrics')}" if data.get("lyrics") else None,
                            "srt_url": f"/media/{data.get('srt')}" if data.get("srt") else None,
                            "vtt_url": f"/media/{data.get('vtt')}" if data.get('vtt') else None,
                            "video_url": f"/media/{data.get('video_file')}" if data.get("video_file") else None,
                        })
                except Exception as e:
                    pass
    return {"songs": songs}

@router.get("/search_youtube")
def search_youtube(q: str):
    from app.youtube import search_youtube_songs
    results = search_youtube_songs(q, limit=8)
    return {"results": results}
@router.get("/profile/{user_id}", response_model=UserProfileOut)
def get_user_profile(user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado.")
        
    is_following = current_user in user.followers
    return UserProfileOut(
        id=user.id,
        username=user.username,
        email=user.email,
        avatar_url=user.avatar_url,
        bio=user.bio,
        created_at=user.created_at,
        following_count=len(user.following),
        followers_count=len(user.followers),
        is_following=is_following
    )

@router.post("/profile/edit", response_model=UserOut)
def edit_profile(
    bio: Optional[str] = Form(None),
    avatar: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if bio is not None:
        current_user.bio = bio
        
    if avatar and avatar.filename:
        # Guardar imagen de avatar
        avatar_ext = os.path.splitext(avatar.filename)[1].lower()
        if avatar_ext in {".jpg", ".jpeg", ".png", ".webp"}:
            avatar_filename = f"avatar_{current_user.id}{avatar_ext}"
            avatar_path = os.path.join(OUTPUT_DIR, avatar_filename)
            try:
                with open(avatar_path, "wb") as buffer:
                    buffer.write(avatar.file.read())
                current_user.avatar_url = f"/media/{avatar_filename}"
            except Exception as e:
                raise HTTPException(status_code=500, detail=f"No se pudo guardar el avatar: {str(e)}")
                
    db.commit()
    db.refresh(current_user)
    return current_user

@router.post("/follow/{user_id}")
def follow_user(user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="No puedes seguirte a ti mismo.")
        
    user_to_follow = db.query(User).filter(User.id == user_id).first()
    if not user_to_follow:
        raise HTTPException(status_code=404, detail="Usuario a seguir no encontrado.")
        
    if current_user in user_to_follow.followers:
        # Dejar de seguir (Unfollow)
        user_to_follow.followers.remove(current_user)
        message = "Dejaste de seguir a este usuario."
    else:
        # Seguir (Follow)
        user_to_follow.followers.append(current_user)
        message = "Comenzaste a seguir a este usuario."
        
    db.commit()
    return {"message": message, "is_following": current_user in user_to_follow.followers}

# Endpoints de Publicación de Covers
@router.post("/covers", response_model=CoverOut)
def publish_cover(
    title: str = Form(...),
    description: Optional[str] = Form(""),
    duration: int = Form(0),
    job_id: Optional[str] = Form(None), # Si viene de una canción del catálogo
    vocals_file: Optional[UploadFile] = File(None), # Grabación cruda del micrófono
    effects_vocal_volume: float = Form(1.0),
    effects_instrumental_volume: float = Form(1.0),
    effects_reverb: float = Form(0.0), # Reverb wet mix (0.0 a 1.0)
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Sube y publica un Cover. Mezcla la voz grabada con la pista instrumental
    (si se provee el job_id) aplicando los niveles de volumen y efectos indicados.
    """
    instrumental_url = None
    lyrics_url = None
    mixed_filename = None
    video_url = None
    
    # Si viene ligado a un trabajo de karaoke del catálogo
    if job_id:
        status_path = os.path.join(OUTPUT_DIR, f"{job_id}_status.json")
        if os.path.exists(status_path):
            with open(status_path, "r", encoding="utf-8") as f:
                job_data = json.load(f)
                
            lyrics_url = f"/media/{job_data.get('lyrics')}" if job_data.get("lyrics") else None
            
            # Buscar instrumental
            for f_name in job_data.get("files", []):
                if "(Instrumental)" in f_name:
                    instrumental_url = f"/media/{f_name}"
                    instrumental_path = os.path.join(OUTPUT_DIR, f_name)
                    break
            
            # Si el usuario subió su grabación vocal, realizamos la mezcla FFmpeg
            if vocals_file and vocals_file.filename and instrumental_url:
                vocals_ext = os.path.splitext(vocals_file.filename)[1].lower()
                temp_vocals_name = f"temp_vocals_{job_id}_{current_user.id}{vocals_ext}"
                temp_vocals_path = os.path.join(OUTPUT_DIR, temp_vocals_name)
                
                # Guardar voz cruda
                with open(temp_vocals_path, "wb") as buffer:
                    buffer.write(vocals_file.file.read())
                
                # Nombre del archivo mezclado de salida
                mixed_filename = f"mix_{job_id}_{current_user.id}_{int(datetime.utcnow().timestamp())}.mp3"
                mixed_path = os.path.join(OUTPUT_DIR, mixed_filename)
                
                # Construir comando FFmpeg para mezclar vocal e instrumental
                # - vocal_vol = effects_vocal_volume
                # - inst_vol = effects_instrumental_volume
                # - Se puede aplicar reverb (simple alet-echo para simular espacio)
                reverb_filter = ""
                if effects_reverb > 0.0:
                    # Filtro de eco/reverb básico en FFmpeg: aecho=0.8:0.88:60:0.4
                    decay = min(0.9, 0.4 + effects_reverb * 0.4)
                    reverb_filter = f",aecho=0.8:0.88:60:{decay}"
                
                # Mezclar usando filter_complex en FFmpeg
                # [0:a] volumen instrumental, [1:a] volumen vocal + efectos -> mix
                cmd = (
                    f'ffmpeg -y -i "{instrumental_path}" -i "{temp_vocals_path}" -filter_complex '
                    f'"[0:a]volume={effects_instrumental_volume}[a1]; '
                    f'[1:a]volume={effects_vocal_volume}{reverb_filter}[a2]; '
                    f'[a1][a2]amix=inputs=2:duration=longest[out]" '
                    f'-map "[out]" -b:a 192k "{mixed_path}"'
                )
                
                try:
                    import subprocess
                    subprocess.run(cmd, shell=True, check=True)
                except Exception as fe:
                    print(f"Error al mezclar con FFmpeg: {fe}")
                    # En caso de fallo, guardamos la pista de voz directamente como el mix
                    import shutil
                    shutil.copy(temp_vocals_path, mixed_path)
                finally:
                    # Limpiar vocal temporal
                    if os.path.exists(temp_vocals_path):
                        os.remove(temp_vocals_path)
    
    # Si no hay mezcla (subida directa de un archivo de audio ya mezclado)
    if not mixed_filename and vocals_file and vocals_file.filename:
        vocals_ext = os.path.splitext(vocals_file.filename)[1].lower()
        mixed_filename = f"direct_mix_{current_user.id}_{int(datetime.utcnow().timestamp())}{vocals_ext}"
        mixed_path = os.path.join(OUTPUT_DIR, mixed_filename)
        with open(mixed_path, "wb") as buffer:
            buffer.write(vocals_file.file.read())

    # Registrar el cover en la base de datos
    new_cover = Cover(
        title=title,
        description=description,
        user_id=current_user.id,
        instrumental_path=instrumental_url,
        vocal_path=None, # La voz cruda ya fue mezclada o subida
        mix_path=f"/media/{mixed_filename}" if mixed_filename else None,
        video_path=video_url,
        lyrics_path=lyrics_url,
        duration=duration
    )
    db.add(new_cover)
    db.commit()
    db.refresh(new_cover)
    
    # Mapear al modelo de salida
    return CoverOut(
        id=new_cover.id,
        title=new_cover.title,
        description=new_cover.description,
        user=UserOut.from_orm(new_cover.user),
        instrumental_path=new_cover.instrumental_path,
        vocal_path=new_cover.vocal_path,
        mix_path=new_cover.mix_path,
        video_path=new_cover.video_path,
        lyrics_path=new_cover.lyrics_path,
        duration=new_cover.duration,
        likes_count=0,
        has_liked=False,
        created_at=new_cover.created_at
    )

@router.get("/covers", response_model=List[CoverOut])
@router.get("/feed", response_model=List[CoverOut])
def list_covers(
    user_id: Optional[int] = None,
    feed_type: str = "global", # global, following
    db: Session = Depends(get_db)
):
    query = db.query(Cover)
    
    if user_id:
        query = query.filter(Cover.user_id == user_id)
        
    covers = query.order_by(Cover.created_at.desc()).all()
    
    # Resolver cada cover
    result = []
    for c in covers:
        likes_count = db.query(Like).filter(Like.cover_id == c.id).count()
        
        # Sincronizar contador
        if c.likes_count != likes_count:
            c.likes_count = likes_count
            db.commit()
            
        result.append(CoverOut(
            id=c.id,
            title=c.title,
            description=c.description,
            user=UserOut.from_orm(c.user),
            instrumental_path=c.instrumental_path,
            vocal_path=c.vocal_path,
            mix_path=c.mix_path,
            video_path=c.video_path,
            lyrics_path=c.lyrics_path,
            duration=c.duration,
            likes_count=likes_count,
            has_liked=False,
            created_at=c.created_at
        ))
    return result

# Endpoints de Me Gusta (Likes)
@router.post("/like/{cover_id}")
def like_cover(cover_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    cover = db.query(Cover).filter(Cover.id == cover_id).first()
    if not cover:
        raise HTTPException(status_code=404, detail="Cover no encontrado.")
        
    like = db.query(Like).filter(Like.cover_id == cover_id, Like.user_id == current_user.id).first()
    if like:
        # Quitar like
        db.delete(like)
        message = "Ya no te gusta este cover."
        liked = False
    else:
        # Dar like
        new_like = Like(user_id=current_user.id, cover_id=cover_id)
        db.add(new_like)
        message = "Te gusta este cover."
        liked = True
        
    db.commit()
    likes_count = db.query(Like).filter(Like.cover_id == cover_id).count()
    cover.likes_count = likes_count
    db.commit()
    
    return {"message": message, "has_liked": liked, "likes_count": likes_count}

# Endpoints de Comentarios
@router.post("/comment/{cover_id}", response_model=CommentOut)
def comment_cover(
    cover_id: int,
    comment_in: CommentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    cover = db.query(Cover).filter(Cover.id == cover_id).first()
    if not cover:
        raise HTTPException(status_code=404, detail="Cover no encontrado.")
        
    comment = Comment(
        content=comment_in.content,
        user_id=current_user.id,
        cover_id=cover_id
    )
    db.add(comment)
    db.commit()
    db.refresh(comment)
    return comment

@router.get("/comments/{cover_id}", response_model=List[CommentOut])
def get_comments(cover_id: int, db: Session = Depends(get_db)):
    comments = db.query(Comment).filter(Comment.cover_id == cover_id).order_by(Comment.created_at.desc()).all()
    return comments

# ==========================================
# 🎁 REGALOS VIRTUALES Y ECONOMÍA SOCIAL
# ==========================================

class GiftOut(BaseModel):
    id: int
    name: str
    icon: str
    price: int
    animation: str
    category: str

    class Config:
        from_attributes = True

class SendGiftIn(BaseModel):
    gift_id: int
    receiver_id: int
    cover_id: Optional[int] = None
    room_id: Optional[int] = None

class SendGiftOut(BaseModel):
    success: bool
    message: str
    gift: GiftOut
    sender_coins: int
    receiver_gems: int

class WalletOut(BaseModel):
    coins: int
    gems: int
    transactions_count: int

@router.get("/gifts", response_model=List[GiftOut])
def list_gifts(db: Session = Depends(get_db)):
    return db.query(Gift).all()

@router.post("/gifts/send", response_model=SendGiftOut)
def send_gift(
    payload: SendGiftIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    gift = db.query(Gift).filter(Gift.id == payload.gift_id).first()
    if not gift:
        raise HTTPException(status_code=404, detail="Regalo no encontrado.")
        
    receiver = db.query(User).filter(User.id == payload.receiver_id).first()
    if not receiver:
        raise HTTPException(status_code=404, detail="Destinatario no encontrado.")
        
    if current_user.coins < gift.price:
        raise HTTPException(status_code=400, detail="Saldo insuficiente de monedas para enviar este regalo.")
        
    # Deducir monedas al emisor y acreditar gemas/diamantes al receptor
    current_user.coins -= gift.price
    gems_awarded = int(gift.price * 0.7) # 70% de conversión en gemas monetizables
    receiver.gems += gems_awarded
    
    tx = GiftTransaction(
        sender_id=current_user.id,
        receiver_id=receiver.id,
        room_id=payload.room_id,
        cover_id=payload.cover_id,
        gift_id=gift.id,
        coins_amount=gift.price
    )
    db.add(tx)
    db.commit()
    db.refresh(current_user)
    db.refresh(receiver)
    
    return SendGiftOut(
        success=True,
        message=f"¡Enviaste {gift.name} a {receiver.username}!",
        gift=GiftOut.from_orm(gift),
        sender_coins=current_user.coins,
        receiver_gems=receiver.gems
    )

@router.get("/wallet", response_model=WalletOut)
def get_wallet(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    tx_count = db.query(GiftTransaction).filter(
        (GiftTransaction.sender_id == current_user.id) | (GiftTransaction.receiver_id == current_user.id)
    ).count()
    return WalletOut(
        coins=current_user.coins or 0,
        gems=current_user.gems or 0,
        transactions_count=tx_count
    )

@router.post("/wallet/recharge")
def recharge_coins(
    amount: int = Form(500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    current_user.coins = (current_user.coins or 0) + amount
    db.commit()
    db.refresh(current_user)
    return {"message": f"¡Recarga exitosa! +{amount} monedas acreditadas.", "new_balance": current_user.coins}

# ==========================================
# ⚡ HISTORIAS / MOMENTOS DE 24 HORAS
# ==========================================

class StoryOut(BaseModel):
    id: int
    user: UserOut
    media_url: str
    caption: str
    created_at: datetime
    expires_at: datetime

    class Config:
        from_attributes = True

@router.get("/stories/active", response_model=List[StoryOut])
def get_active_stories(db: Session = Depends(get_db)):
    now = datetime.utcnow()
    stories = db.query(Story).filter(Story.expires_at > now).order_by(Story.created_at.desc()).all()
    return stories

@router.post("/stories/create", response_model=StoryOut)
def create_story(
    caption: str = Form(""),
    media_file: UploadFile = File(None),
    media_url: str = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    import uuid
    final_media_url = media_url or "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400&auto=format&fit=crop&q=80"
    
    if media_file and media_file.filename:
        ext = os.path.splitext(media_file.filename)[1].lower()
        filename = f"story_{uuid.uuid4().hex}{ext}"
        filepath = os.path.join(OUTPUT_DIR, filename)
        with open(filepath, "wb") as f:
            f.write(media_file.file.read())
        final_media_url = f"/media/{filename}"
        
    now = datetime.utcnow()
    expires = now + datetime.timedelta(hours=24)
    story = Story(
        user_id=current_user.id,
        media_url=final_media_url,
        caption=caption,
        created_at=now,
        expires_at=expires
    )
    db.add(story)
    db.commit()
    db.refresh(story)
    return story

# ==========================================
# 📚 CANCIONERO & SHAREBOOK (STARMAKER TRACKS)
# ==========================================

CURATED_GLOBAL_LIBRARY = [
    {"id": "cat_1", "title": "Vivir Mi Vida", "artist": "Marc Anthony", "genre": "Salsa", "query": "Marc Anthony Vivir Mi Vida", "file": "vivir_mi_vida_karaoke.mp3", "lyrics_file": "vivir_mi_vida_lyrics.json"},
    {"id": "cat_2", "title": "El Cantante", "artist": "Héctor Lavoe", "genre": "Salsa", "query": "Hector Lavoe El Cantante", "file": "el_cantante_karaoke.mp3", "lyrics_file": "el_cantante_lyrics.json"},
    {"id": "cat_3", "title": "Periódico de Ayer", "artist": "Héctor Lavoe", "genre": "Salsa", "query": "Hector Lavoe Periodico de Ayer", "file": "periodico_de_ayer_karaoke.mp3", "lyrics_file": "periodico_de_ayer_lyrics.json"},
    {"id": "cat_4", "title": "La Rebelión (No Le Pegue a la Negra)", "artist": "Joe Arroyo", "genre": "Salsa", "query": "Joe Arroyo La Rebelion", "file": "la_rebelion_karaoke.mp3", "lyrics_file": "la_rebelion_lyrics.json"},
    {"id": "cat_5", "title": "Llorarás", "artist": "Oscar D'León", "genre": "Salsa", "query": "Oscar D Leon Lloraras", "file": "lloraras_karaoke.mp3", "lyrics_file": "lloraras_lyrics.json"},
    {"id": "cat_6", "title": "Bachata Rosa", "artist": "Juan Luis Guerra", "genre": "Bachata", "query": "Juan Luis Guerra Bachata Rosa", "file": "bachata_rosa_karaoke.mp3", "lyrics_file": "bachata_rosa_lyrics.json"},
    {"id": "cat_7", "title": "Propuesta Indecente", "artist": "Romeo Santos", "genre": "Bachata", "query": "Romeo Santos Propuesta Indecente", "file": "propuesta_indecente_karaoke.mp3", "lyrics_file": "propuesta_indecente_lyrics.json"},
    {"id": "cat_8", "title": "Antología", "artist": "Shakira", "genre": "Baladas", "query": "Shakira Antologia", "file": "antologia_karaoke.mp3", "lyrics_file": "antologia_lyrics.json"},
    {"id": "cat_9", "title": "Despacito", "artist": "Luis Fonsi & Daddy Yankee", "genre": "Urbano", "query": "Luis Fonsi Despacito", "file": "despacito_karaoke.mp3", "lyrics_file": "despacito_lyrics.json"},
    {"id": "cat_10", "title": "Baby", "artist": "Justin Bieber ft. Ludacris", "genre": "Pop Clásico", "query": "Justin Bieber Baby", "file": "ae6cbb7becbf41a9ad9fb65a0312c89f_(Instrumental).mp3", "lyrics_file": "ae6cbb7becbf41a9ad9fb65a0312c89f_lyrics.json"},
]

@router.get("/library/songs")
def get_library_songs(genre: Optional[str] = None, db: Session = Depends(get_db)):
    covers = db.query(Cover).order_by(Cover.created_at.desc()).all()
    results = []
    
    # 1. Añadir pistas procesadas y subidas por usuarios
    for c in covers:
        results.append({
            "id": f"cover_{c.id}",
            "title": c.title,
            "artist": c.user.username if c.user else "DiviVoice",
            "genre": "Comunidad",
            "instrumental_url": f"/media/{c.instrumental_path}" if c.instrumental_path else None,
            "lyrics_url": f"/media/{c.lyrics_path}" if c.lyrics_path else None,
            "video_url": f"/media/{c.video_path}" if c.video_path else None,
            "creator_username": c.user.username if c.user else "DiviVoice",
            "is_ready": bool(c.instrumental_path),
            "source": "sharebook"
        })
        
    # 2. Añadir catálogo base curado (100% escuchable y funcional con audio real)
    for item in CURATED_GLOBAL_LIBRARY:
        if genre and genre.lower() != "todos" and item["genre"].lower() != genre.lower():
            continue
        results.append({
            "id": item["id"],
            "title": item["title"],
            "artist": item["artist"],
            "genre": item["genre"],
            "query": item["query"],
            "instrumental_url": f"/media/{item['file']}",
            "lyrics_url": f"/media/{item['lyrics_file']}" if item.get("lyrics_file") else None,
            "video_url": None,
            "creator_username": "Catálogo Oficial",
            "is_ready": True,
            "source": "catalog"
        })
        
    return results

@router.get("/library/search")
def search_library(q: str, db: Session = Depends(get_db)):
    q_lower = q.lower().strip()
    matches = []
    
    # 1. Buscar en creaciones de la comunidad / canciones guardadas
    covers = db.query(Cover).all()
    for c in covers:
        if q_lower in c.title.lower() or (c.user and q_lower in c.user.username.lower()):
            matches.append({
                "id": f"cover_{c.id}",
                "title": c.title,
                "artist": c.user.username if c.user else "Comunidad",
                "genre": "Comunidad",
                "instrumental_url": f"/media/{c.instrumental_path}" if c.instrumental_path else None,
                "lyrics_url": f"/media/{c.lyrics_path}" if c.lyrics_path else None,
                "is_ready": bool(c.instrumental_path),
                "source": "community"
            })

    # 2. Buscar en catálogo curado
    for item in CURATED_GLOBAL_LIBRARY:
        if q_lower in item["title"].lower() or q_lower in item["artist"].lower() or q_lower in item["genre"].lower():
            matches.append({
                "id": item["id"],
                "title": item["title"],
                "artist": item["artist"],
                "genre": item["genre"],
                "query": item["query"],
                "instrumental_url": f"/media/{item['file']}",
                "lyrics_url": f"/media/{item['lyrics_file']}" if item.get("lyrics_file") else None,
                "is_ready": True,
                "source": "catalog"
            })
            
    # 3. Si no existe en la biblioteca, permitir buscar y extraer directamente
    if not matches:
        matches.append({
            "id": f"custom_{uuid.uuid4().hex[:6]}",
            "title": q.title(),
            "artist": "Buscar & Extraer con IA",
            "genre": "Extracción Automática",
            "query": q,
            "instrumental_url": None,
            "lyrics_url": None,
            "is_ready": False,
            "source": "online"
        })
    return matches


@router.post("/library/songs/publish")
def publish_track_to_sharebook(
    title: str = Form(...),
    job_id: str = Form(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    inst_filename = f"{job_id}_instrumental.mp3"
    lyrics_filename = f"{job_id}_lyrics.lrc"
    video_filename = f"{job_id}_karaoke.mp4"

    cover = Cover(
        title=title,
        description=f"Pista instrumental para Karaoke por @{current_user.username}",
        user_id=current_user.id,
        instrumental_path=inst_filename if os.path.exists(os.path.join(OUTPUT_DIR, inst_filename)) else None,
        lyrics_path=lyrics_filename if os.path.exists(os.path.join(OUTPUT_DIR, lyrics_filename)) else None,
        video_path=video_filename if os.path.exists(os.path.join(OUTPUT_DIR, video_filename)) else None,
        duration=180
    )
    db.add(cover)
    db.commit()
    db.refresh(cover)
    return {"message": "¡Pista publicada exitosamente en el Cancionero / Sharebook!", "song_id": cover.id}

@router.get("/user/creations")
def get_user_creations(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    user_covers = db.query(Cover).filter(Cover.user_id == current_user.id).order_by(Cover.created_at.desc()).all()
    results = []
    for c in user_covers:
        results.append({
            "id": c.id,
            "title": c.title,
            "instrumental_url": f"/media/{c.instrumental_path}" if c.instrumental_path else None,
            "video_url": f"/media/{c.video_path}" if c.video_path else None,
            "likes_count": c.likes_count or 0,
            "created_at": c.created_at.isoformat()
        })
    return results

@router.post("/library/prepare-catalog-song")
def prepare_catalog_song(
    query: str = Form(...),
    title: str = Form(...),
    artist: str = Form("DiviVoice")
):
    from app.separator import start_separation_job
    from app.config import DEFAULT_MODEL
    job_id = f"cat_{uuid.uuid4().hex[:8]}"
    start_separation_job(
        job_id=job_id,
        input_path=None,
        model_filename=DEFAULT_MODEL,
        whisper_model="base",
        language="es",
        create_video=True,
        youtube_url=query if ("youtube.com" in query or "youtu.be" in query) else f"ytsearch1:{query}"
    )
    return {
        "job_id": job_id,
        "title": title,
        "artist": artist,
        "status": "pending"
    }




