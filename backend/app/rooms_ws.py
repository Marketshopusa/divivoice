import json
import logging
from typing import Dict, List, Set, Optional
from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, Form
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.database import get_db, SessionLocal
from app.models import User, Room, RoomSeat, RoomQueue
from app.auth import get_current_user, UserOut

logger = logging.getLogger("divivoice-rooms")
router = APIRouter(prefix="/api/rooms", tags=["rooms"])

# Pydantic schemas
class RoomCreate(BaseModel):
    name: str

class SeatOut(BaseModel):
    seat_index: int
    user: Optional[UserOut] = None
    is_muted: bool

    class Config:
        from_attributes = True

class QueueOut(BaseModel):
    id: int
    user: UserOut
    song_title: str
    youtube_url: Optional[str]
    job_id: Optional[str]
    status: str

    class Config:
        from_attributes = True

class RoomOut(BaseModel):
    id: int
    name: str
    host: UserOut
    is_active: bool
    active_singer: Optional[UserOut] = None
    current_song_title: Optional[str] = None
    current_song_job_id: Optional[str] = None
    seats: List[SeatOut] = []
    queue: List[QueueOut] = []

    class Config:
        from_attributes = True

# REST Endpoints
@router.post("/create", response_model=RoomOut)
def create_room(room_in: RoomCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Desactivar salas anteriores creadas por este host
    db.query(Room).filter(Room.host_id == current_user.id, Room.is_active == True).update({"is_active": False})
    db.commit()

    # Crear nueva sala
    new_room = Room(name=room_in.name, host_id=current_user.id)
    db.add(new_room)
    db.commit()
    db.refresh(new_room)

    # Crear 8 asientos vacíos por defecto
    for i in range(8):
        seat = RoomSeat(room_id=new_room.id, seat_index=i, user_id=None)
        db.add(seat)
    db.commit()
    db.refresh(new_room)
    
    return new_room

@router.get("/", response_model=List[RoomOut])
def list_active_rooms(db: Session = Depends(get_db)):
    return db.query(Room).filter(Room.is_active == True).order_by(Room.created_at.desc()).all()

@router.get("/{room_id}", response_model=RoomOut)
def get_room_details(room_id: int, db: Session = Depends(get_db)):
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Sala no encontrada.")
    return room

@router.get("/{room_id}/queue", response_model=List[QueueOut])
def get_room_queue(room_id: int, db: Session = Depends(get_db)):
    return db.query(RoomQueue).filter(RoomQueue.room_id == room_id).order_by(RoomQueue.created_at.asc()).all()

@router.post("/{room_id}/queue/add", response_model=QueueOut)
def add_song_to_queue(
    room_id: int,
    song_title: str = Form(...),
    youtube_url: Optional[str] = Form(None),
    job_id: Optional[str] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Sala no encontrada.")

    new_q = RoomQueue(
        room_id=room_id,
        user_id=current_user.id,
        song_title=song_title,
        youtube_url=youtube_url,
        job_id=job_id,
        status="pending"
    )
    db.add(new_q)
    db.commit()
    db.refresh(new_q)
    return new_q

@router.post("/{room_id}/close")
def close_room(room_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Sala no encontrada.")
    if room.host_id != current_user.id:
        raise HTTPException(status_code=403, detail="Solo el anfitrión puede cerrar la sala.")
    room.is_active = False
    db.commit()
    return {"status": "success", "message": "Sala finalizada."}




# WebSocket Connection Manager
class RoomConnectionManager:
    def __init__(self):
        # Mapea room_id -> lista de conexiones WebSocket activas
        self.active_connections: Dict[int, List[WebSocket]] = {}
        # Mapea websocket -> user_id
        self.ws_users: Dict[WebSocket, int] = {}

    async def connect(self, websocket: WebSocket, room_id: int, user_id: int):
        await websocket.accept()
        if room_id not in self.active_connections:
            self.active_connections[room_id] = []
        self.active_connections[room_id].append(websocket)
        self.ws_users[websocket] = user_id
        
        logger.info(f"Usuario {user_id} conectado a la sala {room_id} mediante WS")

    def disconnect(self, websocket: WebSocket, room_id: int):
        if room_id in self.active_connections:
            if websocket in self.active_connections[room_id]:
                self.active_connections[room_id].remove(websocket)
        if websocket in self.ws_users:
            del self.ws_users[websocket]
            
        logger.info(f"Conexión WS cerrada en sala {room_id}")

    async def broadcast_to_room(self, room_id: int, message: dict):
        if room_id in self.active_connections:
            payload = json.dumps(message)
            for connection in self.active_connections[room_id]:
                try:
                    await connection.send_text(payload)
                except Exception as e:
                    logger.warning(f"Error al enviar mensaje WS a un cliente en sala {room_id}: {e}")

manager = RoomConnectionManager()

@router.websocket("/ws/{room_id}/{user_id}")
async def room_websocket_endpoint(websocket: WebSocket, room_id: int, user_id: int):
    # Validar que la sala y el usuario existan en una sesión local separada
    db = SessionLocal()
    user = db.query(User).filter(User.id == user_id).first()
    room = db.query(Room).filter(Room.id == room_id).first()
    
    if not user or not room:
        await websocket.close(code=1008)
        db.close()
        return

    await manager.connect(websocket, room_id, user_id)
    
    # Broadcast del ingreso de usuario
    user_data = {"id": user.id, "username": user.username, "avatar_url": user.avatar_url}
    await manager.broadcast_to_room(room_id, {
        "event": "user_joined",
        "user": user_data
    })

    try:
        while True:
            # Esperar mensajes del cliente
            data = await websocket.receive_text()
            message = json.loads(data)
            action = message.get("action")
            
            # Recargar sala de base de datos para asegurar consistencia
            db.refresh(room)

            if action == "chat_message":
                content = message.get("content", "")
                if content.strip():
                    await manager.broadcast_to_room(room_id, {
                        "event": "chat_message",
                        "user": user_data,
                        "content": content
                    })
                    
            elif action == "gift":
                gift_name = message.get("gift_name", "rose")
                target_user_id = message.get("target_user_id")
                target_user = db.query(User).filter(User.id == target_user_id).first()
                target_name = target_user.username if target_user else "la sala"
                
                await manager.broadcast_to_room(room_id, {
                    "event": "gift_sent",
                    "user": user_data,
                    "gift_name": gift_name,
                    "target_user_id": target_user_id,
                    "target_username": target_name
                })
                
            elif action in ("occupy_seat", "seat_update"):
                seat_idx = message.get("seat_index")
                target_user = message.get("user")
                if seat_idx is not None:
                    # Normalizar si viene 1-indexed (1..8) o 0-indexed (0..7)
                    db_idx = (seat_idx - 1) if seat_idx >= 1 and action == "seat_update" and seat_idx <= 8 else seat_idx
                    if 0 <= db_idx < 8:
                        if action == "seat_update" and target_user is None:
                            # Liberar asiento
                            db.query(RoomSeat).filter(RoomSeat.room_id == room_id, RoomSeat.seat_index == db_idx).update({"user_id": None})
                            db.commit()
                            await manager.broadcast_to_room(room_id, {
                                "event": "seat_updated",
                                "seat_index": db_idx,
                                "user": None,
                                "is_muted": False
                            })
                        else:
                            # Desocupar cualquier otro asiento donde esté el usuario en esta sala
                            db.query(RoomSeat).filter(RoomSeat.room_id == room_id, RoomSeat.user_id == user_id).update({"user_id": None})
                            # Ocupar el nuevo asiento
                            seat = db.query(RoomSeat).filter(RoomSeat.room_id == room_id, RoomSeat.seat_index == db_idx).first()
                            if seat:
                                seat.user_id = user_id
                                seat.is_muted = False
                                db.commit()
                                
                            await manager.broadcast_to_room(room_id, {
                                "event": "seat_updated",
                                "seat_index": db_idx,
                                "user": user_data or target_user,
                                "is_muted": False
                            })
                        
            elif action == "vacate_seat":
                # Buscar y liberar asiento
                seat = db.query(RoomSeat).filter(RoomSeat.room_id == room_id, RoomSeat.user_id == user_id).first()
                if seat:
                    seat_idx = seat.seat_index
                    seat.user_id = None
                    db.commit()
                    
                    await manager.broadcast_to_room(room_id, {
                        "event": "seat_updated",
                        "seat_index": seat_idx,
                        "user": None,
                        "is_muted": False
                    })
                    
            elif action == "mute_seat":
                is_muted = message.get("is_muted", True)
                seat = db.query(RoomSeat).filter(RoomSeat.room_id == room_id, RoomSeat.user_id == user_id).first()
                if seat:
                    seat.is_muted = is_muted
                    db.commit()
                    
                    await manager.broadcast_to_room(room_id, {
                        "event": "seat_updated",
                        "seat_index": seat.seat_index,
                        "user": user_data,
                        "is_muted": is_muted
                    })
                    
            elif action == "add_to_queue":
                song_title = message.get("song_title", "Canción de Karaoke")
                youtube_url = message.get("youtube_url")
                job_id = message.get("job_id")
                
                # Crear petición en la cola
                new_q = RoomQueue(
                    room_id=room_id,
                    user_id=user_id,
                    song_title=song_title,
                    youtube_url=youtube_url,
                    job_id=job_id,
                    status="pending"
                )
                db.add(new_q)
                db.commit()
                db.refresh(new_q)
                
                await manager.broadcast_to_room(room_id, {
                    "event": "queue_updated",
                    "queue_item": {
                        "id": new_q.id,
                        "user": user_data,
                        "song_title": song_title,
                        "job_id": job_id,
                        "status": "pending"
                    }
                })
                
            elif action == "remove_from_queue":
                q_id = message.get("queue_id")
                q_item = db.query(RoomQueue).filter(RoomQueue.id == q_id).first()
                if q_item:
                    db.delete(q_item)
                    db.commit()
                    
                    await manager.broadcast_to_room(room_id, {
                        "event": "queue_removed",
                        "queue_id": q_id
                    })
                    
            elif action == "sing_next_song":
                # Verificar si es el host o está en asientos
                is_host = room.host_id == user_id
                is_on_seat = db.query(RoomSeat).filter(RoomSeat.room_id == room_id, RoomSeat.user_id == user_id).first() is not None
                
                if is_host or is_on_seat:
                    # Obtener primer elemento pendiente de la cola
                    next_item = db.query(RoomQueue).filter(RoomQueue.room_id == room_id, RoomQueue.status == "pending").order_by(RoomQueue.created_at.asc()).first()
                    if next_item:
                        next_item.status = "singing"
                        
                        room.active_singer_id = next_item.user_id
                        room.current_song_title = next_item.song_title
                        room.current_song_job_id = next_item.job_id
                        db.commit()
                        
                        singer = db.query(User).filter(User.id == next_item.user_id).first()
                        singer_data = {"id": singer.id, "username": singer.username, "avatar_url": singer.avatar_url}
                        
                        # Buscar los detalles del track en base al job_id (para sincronizar letras y audios)
                        instrumental_url = None
                        lyrics_url = None
                        
                        if next_item.job_id:
                            # Cargar JSON de estado
                            status_path = os.path.join(OUTPUT_DIR, f"{next_item.job_id}_status.json")
                            if os.path.exists(status_path):
                                try:
                                    with open(status_path, "r", encoding="utf-8") as f:
                                        job_data = json.load(f)
                                    lyrics_url = f"/media/{job_data.get('lyrics')}" if job_data.get("lyrics") else None
                                    for out_f in job_data.get("files", []):
                                        if "(Instrumental)" in out_f:
                                            instrumental_url = f"/media/{out_f}"
                                            break
                                except Exception:
                                    pass
                        
                        await manager.broadcast_to_room(room_id, {
                            "event": "singing_started",
                            "singer": singer_data,
                            "song_title": next_item.song_title,
                            "job_id": next_item.job_id,
                            "instrumental_url": instrumental_url,
                            "lyrics_url": lyrics_url,
                            "queue_id": next_item.id
                        })
                        
            elif action == "finish_singing":
                if room.active_singer_id == user_id or room.host_id == user_id:
                    # Finalizar canto actual
                    current_singing = db.query(RoomQueue).filter(RoomQueue.room_id == room_id, RoomQueue.status == "singing").first()
                    if current_singing:
                        current_singing.status = "completed"
                        db.delete(current_singing) # eliminar de la cola al completar
                    
                    room.active_singer_id = None
                    room.current_song_title = None
                    room.current_song_job_id = None
                    db.commit()
                    
                    await manager.broadcast_to_room(room_id, {
                        "event": "singing_finished"
                    })

            elif action == "play_track":
                # Anfitrión o cantante reproduce una pista en la sala para todos los espectadores
                song_title = message.get("song_title", "Pista en Vivo")
                instrumental_url = message.get("instrumental_url")
                lyrics_url = message.get("lyrics_url")

                room.current_song_title = song_title
                db.commit()

                await manager.broadcast_to_room(room_id, {
                    "event": "singing_started",
                    "singer": user_data,
                    "song_title": song_title,
                    "instrumental_url": instrumental_url,
                    "lyrics_url": lyrics_url
                })

            elif action == "stop_track":
                room.current_song_title = None
                db.commit()
                await manager.broadcast_to_room(room_id, {
                    "event": "singing_finished"
                })


                    
            elif action == "heart_reaction":
                color = message.get("color", "red")
                await manager.broadcast_to_room(room_id, {
                    "event": "heart_reaction",
                    "user": user_data,
                    "color": color
                })
                
            elif action == "camera_toggle":
                is_active = message.get("is_active", True)
                await manager.broadcast_to_room(room_id, {
                    "event": "camera_stream_updated",
                    "user": user_data,
                    "is_active": is_active
                })
                
            elif action == "webrtc_signal":
                target_user_id = message.get("target_user_id")
                signal_data = message.get("data")
                await manager.broadcast_to_room(room_id, {
                    "event": "webrtc_signal",
                    "sender_id": user_id,
                    "target_user_id": target_user_id,
                    "data": signal_data
                })

    except WebSocketDisconnect:
        manager.disconnect(websocket, room_id)
        
        # Desocupar asiento del usuario al desconectarse
        seat = db.query(RoomSeat).filter(RoomSeat.room_id == room_id, RoomSeat.user_id == user_id).first()
        if seat:
            seat_idx = seat.seat_index
            seat.user_id = None
            db.commit()
            await manager.broadcast_to_room(room_id, {
                "event": "seat_updated",
                "seat_index": seat_idx,
                "user": None,
                "is_muted": False
            })
            
        # Si el cantante se desconecta, detener canto
        if room.active_singer_id == user_id:
            db.query(RoomQueue).filter(RoomQueue.room_id == room_id, RoomQueue.status == "singing").update({"status": "completed"})
            room.active_singer_id = None
            room.current_song_title = None
            room.current_song_job_id = None
            db.commit()
            await manager.broadcast_to_room(room_id, {
                "event": "singing_finished"
            })
            
        await manager.broadcast_to_room(room_id, {
            "event": "user_left",
            "user": user_data
        })
    finally:
        db.close()
