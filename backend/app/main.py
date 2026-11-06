import os
import uuid
import json
import logging
from fastapi import FastAPI, UploadFile, File, Form, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse

from app.config import UPLOAD_DIR, OUTPUT_DIR, LOGO_DIR, DEFAULT_MODEL
from app.separator import start_separation_job, jobs_status
from app.database import Base, engine
from app.auth import router as auth_router
from app.social import router as social_router
from app.rooms_ws import router as rooms_router

# Inicializar Base de Datos SQLite y datos iniciales
Base.metadata.create_all(bind=engine)
from app.seed_data import seed_initial_data
seed_initial_data()

logger = logging.getLogger("divivoice-api")

app = FastAPI(title="DiviVoice API", version="1.0.0")

# Habilitar CORS para permitir desarrollo local del Frontend en otros puertos
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Incluir Routers de DiviVoice
app.include_router(auth_router)
app.include_router(social_router)
app.include_router(rooms_router)

# Middleware para evitar el almacenamiento en caché de archivos HTML, JS, CSS y JSON en desarrollo
@app.middleware("http")
async def add_no_cache_headers(request, call_next):
    response = await call_next(request)
    path = request.url.path.lower()
    if path.endswith((".html", ".js", ".css", ".json")) or path == "/":
        response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response


# Endpoint para subir y separar audio (y opcionalmente generar video directamente, por archivo o enlace de YouTube)
@app.post("/api/separate")
async def separate_audio_endpoint(
    file: UploadFile = File(None),
    youtube_url: str = Form(None),
    model: str = Form(DEFAULT_MODEL),
    preserve_backing_vocals: bool = Form(False),
    whisper_model: str = Form("small"),
    language: str = Form("auto"),
    create_video: bool = Form(False),
    aspect_ratio: str = Form("16:9"),
    font_name: str = Form("Arial"),
    active_color: str = Form("#FF0000"),
    inactive_color: str = Form("#FFFF00"),
    background_file: UploadFile = File(None)
):
    if not file and not youtube_url:
        raise HTTPException(
            status_code=400,
            detail="Debe subir un archivo de audio o proveer un enlace de YouTube válido."
        )

    if preserve_backing_vocals:
        model = "mel_band_roformer_karaoke_aufr33_viperx_sdr_10.1956.ckpt"

    # Crear ID de trabajo único
    job_id = uuid.uuid4().hex
    input_path = None
    original_filename = "Importado de YouTube"

    # Si se subió un archivo de audio
    if file and file.filename:
        original_filename = file.filename
        # Validar formato del archivo de audio
        allowed_extensions = {".mp3", ".wav", ".flac", ".ogg", ".m4a"}
        file_ext = os.path.splitext(file.filename)[1].lower()
        if file_ext not in allowed_extensions:
            raise HTTPException(
                status_code=400,
                detail=f"Formato de archivo no soportado. Formatos válidos: {', '.join(allowed_extensions)}"
            )
        
        # Guardar archivo original en la carpeta de uploads
        temp_filename = f"{job_id}{file_ext}"
        input_path = os.path.join(UPLOAD_DIR, temp_filename)
        
        try:
            with open(input_path, "wb") as buffer:
                content = await file.read()
                buffer.write(content)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"No se pudo guardar el archivo: {str(e)}")
    
    # Procesar archivo de fondo si es provisto
    background_filename = None
    if background_file and background_file.filename:
        allowed_bg_extensions = {".jpg", ".jpeg", ".png", ".webp", ".mp4", ".mov", ".avi", ".mkv"}
        bg_ext = os.path.splitext(background_file.filename)[1].lower()
        if bg_ext not in allowed_bg_extensions:
            raise HTTPException(
                status_code=400,
                detail=f"Fondo no soportado. Extensiones válidas: {', '.join(allowed_bg_extensions)}"
            )
            
        background_filename = f"{job_id}_bg{bg_ext}"
        bg_path = os.path.join(OUTPUT_DIR, background_filename)
        try:
            with open(bg_path, "wb") as buffer:
                bg_content = await background_file.read()
                buffer.write(bg_content)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"No se pudo guardar el fondo: {str(e)}")

    # Iniciar la tarea en segundo plano (con soporte para descarga de YouTube)
    start_separation_job(
        job_id,
        input_path,
        model,
        whisper_model=whisper_model,
        language=language,
        create_video=create_video,
        aspect_ratio=aspect_ratio,
        font_name=font_name,
        active_color=active_color,
        inactive_color=inactive_color,
        background_filename=background_filename,
        youtube_url=youtube_url
    )
    
    return {
        "job_id": job_id,
        "status": "pending",
        "original_filename": original_filename
    }

# Endpoint para verificar estado del trabajo
@app.get("/api/status/{job_id}")
def get_job_status(job_id: str):
    status_path = os.path.join(OUTPUT_DIR, f"{job_id}_status.json")
    if os.path.exists(status_path):
        try:
            with open(status_path, "r", encoding="utf-8") as f:
                jobs_status[job_id] = json.load(f)
        except Exception as e:
            logger.error(f"Error al cargar estado de {job_id} desde disco: {e}")
            
    if job_id not in jobs_status:
        # Auto-recuperación si los archivos existen físicamente en disco
        inst = None
        voc = None
        midi = None
        for f in os.listdir(OUTPUT_DIR):
            if job_id in f:
                if "(Instrumental)" in f and f.endswith(".mp3"): inst = f
                elif "(Vocals)" in f and f.endswith(".mp3"): voc = f
                elif "melody.mid" in f or f.endswith(".mid"): midi = f
        if inst and voc:
            jobs_status[job_id] = {
                "status": "completed",
                "progress": 100,
                "error": None,
                "files": [inst, voc],
                "vocals_file": voc,
                "instrumental_file": inst,
                "midi_file": midi or f"{job_id}_melody.mid",
                "lyrics": f"{job_id}_lyrics.json"
            }
        else:
            raise HTTPException(status_code=404, detail="Trabajo no encontrado")

    # Si está en processing pero los archivos ya terminaron de crearse en disco, marcar completed automáticamente
    current = jobs_status[job_id]
    if current.get("status") == "processing":
        has_midi = os.path.exists(os.path.join(OUTPUT_DIR, f"{job_id}_melody.mid"))
        has_lyrics = os.path.exists(os.path.join(OUTPUT_DIR, f"{job_id}_lyrics.json"))
        has_inst = any(job_id in f and "(Instrumental)" in f for f in os.listdir(OUTPUT_DIR))
        if has_inst and has_lyrics:
            current["status"] = "completed"
            current["progress"] = 100
            current["midi_file"] = f"{job_id}_melody.mid" if has_midi else None
            try:
                with open(status_path, "w", encoding="utf-8") as sf:
                    json.dump(current, sf, indent=2)
            except Exception:
                pass

    return jobs_status[job_id]

# Endpoint para eliminar un trabajo y sus archivos asociados
@app.delete("/api/delete/{job_id}")
def delete_job(job_id: str):
    if job_id in jobs_status:
        del jobs_status[job_id]
        
    deleted_files = []
    # Eliminar de uploads
    for filename in os.listdir(UPLOAD_DIR):
        if job_id in filename:
            try:
                os.remove(os.path.join(UPLOAD_DIR, filename))
                deleted_files.append(filename)
            except Exception as e:
                logger.error(f"Error al eliminar upload {filename}: {e}")
                
    # Eliminar de outputs
    for filename in os.listdir(OUTPUT_DIR):
        if job_id in filename:
            try:
                os.remove(os.path.join(OUTPUT_DIR, filename))
                deleted_files.append(filename)
            except Exception as e:
                logger.error(f"Error al eliminar output {filename}: {e}")
                
    return {
        "status": "success",
        "job_id": job_id,
        "deleted_files": deleted_files
    }

# Servir los archivos procesados (resultados) directamente para reproducción o descarga
app.mount("/media", StaticFiles(directory=str(OUTPUT_DIR)), name="media")
app.mount("/logo", StaticFiles(directory=str(LOGO_DIR)), name="logo")

# Endpoints oficiales para las 3 descargas requeridas: Voz, Instrumental y MIDI
@app.get("/api/download/{job_id}/{track_type}")
def download_track(job_id: str, track_type: str):
    """
    Descarga una de las 3 salidas del procesamiento:
    - 'vocals': Pista de voz aislada (.mp3)
    - 'instrumental': Pista instrumental / karaoke (.mp3)
    - 'midi': Archivo MIDI con la melodía y notas (.mid)
    """
    track_type = track_type.lower()
    file_path = None
    download_name = f"{job_id}_{track_type}"
    media_type = "application/octet-stream"

    if track_type in ["vocals", "vocal", "voz"]:
        # Buscar archivo de voz
        for f in os.listdir(OUTPUT_DIR):
            if job_id in f and "(Vocals)" in f and f.endswith(".mp3"):
                file_path = os.path.join(OUTPUT_DIR, f)
                break
        if not file_path:
            alt = os.path.join(OUTPUT_DIR, f"{job_id}_(Vocals).mp3")
            if os.path.exists(alt): file_path = alt
        download_name = f"{job_id}_Voz_Aislada.mp3"
        media_type = "audio/mpeg"

    elif track_type in ["instrumental", "pista", "karaoke"]:
        # Buscar archivo instrumental
        for f in os.listdir(OUTPUT_DIR):
            if job_id in f and "(Instrumental)" in f and f.endswith(".mp3"):
                file_path = os.path.join(OUTPUT_DIR, f)
                break
        if not file_path:
            alt = os.path.join(OUTPUT_DIR, f"{job_id}_(Instrumental).mp3")
            if os.path.exists(alt): file_path = alt
        download_name = f"{job_id}_Pista_Instrumental.mp3"
        media_type = "audio/mpeg"

    elif track_type in ["midi", "mid", "melodia"]:
        # Archivo MIDI
        midi_path = os.path.join(OUTPUT_DIR, f"{job_id}_melody.mid")
        if not os.path.exists(midi_path):
            try:
                from app.midi_generator import generate_midi_from_audio
                # Buscar audio de voz o instrumental de referencia
                ref_audio = None
                for f in os.listdir(OUTPUT_DIR):
                    if job_id in f and f.endswith(".mp3"):
                        ref_audio = os.path.join(OUTPUT_DIR, f)
                        if "(Vocals)" in f: break
                lyrics_json = os.path.join(OUTPUT_DIR, f"{job_id}_lyrics.json")
                lyr_data = None
                if os.path.exists(lyrics_json):
                    with open(lyrics_json, "r", encoding="utf-8") as lf:
                        lyr_data = json.load(lf)
                generate_midi_from_audio(ref_audio, midi_path, lyrics_data=lyr_data)
            except Exception as e:
                logger.error(f"Error generando MIDI bajo demanda para {job_id}: {e}")
        if os.path.exists(midi_path):
            file_path = midi_path
        download_name = f"{job_id}_Melodia.mid"
        media_type = "audio/midi"

    elif track_type in ["lrc", "lyrics_lrc", "letra_lrc"]:
        # Archivo LRC de letras sincronizadas
        lrc_path = os.path.join(OUTPUT_DIR, f"{job_id}_lyrics.lrc")
        if not os.path.exists(lrc_path):
            lyrics_json = os.path.join(OUTPUT_DIR, f"{job_id}_lyrics.json")
            if os.path.exists(lyrics_json):
                try:
                    from app.subtitles import generate_lrc
                    with open(lyrics_json, "r", encoding="utf-8") as lf:
                        lyr_data = json.load(lf)
                    lrc_content = generate_lrc(lyr_data)
                    with open(lrc_path, "w", encoding="utf-8") as sf:
                        sf.write(lrc_content)
                except Exception as le:
                    logger.error(f"Error generando LRC bajo demanda para {job_id}: {le}")
        if os.path.exists(lrc_path):
            file_path = lrc_path
        download_name = f"{job_id}_Letras.lrc"
        media_type = "text/plain; charset=utf-8"

    if not file_path or not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail=f"Archivo '{track_type}' no encontrado para el trabajo {job_id}")

    return FileResponse(
        path=file_path,
        filename=download_name,
        media_type=media_type,
        headers={"Content-Disposition": f'attachment; filename="{download_name}"'}
    )



# Endpoint para listar modelos disponibles (Branding propietario de DiviVoice)
@app.get("/api/models")
def get_available_models():
    return {
        "models": [
            {"id": "Kim_Vocal_2.onnx", "name": "DiviVoice Estándar (Equilibrado - Recomendado)", "type": "vocal_instrumental"},
            {"id": "BS-Roformer_Vocal_2.onnx", "name": "DiviVoice Ultra (Máxima Claridad - Estudio)", "type": "vocal_instrumental"},
            {"id": "HP2-vocals_instrumentals.onnx", "name": "DiviVoice Express (Procesamiento Rápido)", "type": "vocal_instrumental"}
        ]
    }

# Endpoint para obtener las letras en JSON de un trabajo
@app.get("/api/lyrics/{job_id}")
def get_job_lyrics_endpoint(job_id: str):
    lyrics_path = os.path.join(OUTPUT_DIR, f"{job_id}_lyrics.json")
    if os.path.exists(lyrics_path):
        try:
            with open(lyrics_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error leyendo letras: {e}")
    raise HTTPException(status_code=404, detail="Archivo de letras no encontrado")

# Endpoint para auto-alinear letra externa pegada con los tiempos rítmicos reales de la canción
@app.post("/api/align-lyrics")
def align_lyrics_endpoint(
    job_id: str = Form(...),
    raw_text: str = Form(...)
):
    lyrics_path = os.path.join(OUTPUT_DIR, f"{job_id}_lyrics.json")
    if not os.path.exists(lyrics_path):
        raise HTTPException(status_code=404, detail="Letras base no encontradas para este trabajo.")
        
    with open(lyrics_path, "r", encoding="utf-8") as f:
        original_segments = json.load(f)

    import difflib
    lines = [line.strip() for line in raw_text.splitlines() if line.strip()]
    if not lines:
        return {"status": "success", "lyrics": original_segments}

    orig_texts = [s.get("text", "").strip() for s in original_segments]
    
    if len(lines) == len(original_segments):
        new_segments = []
        for idx, line in enumerate(lines):
            seg = original_segments[idx]
            words = line.split()
            duration = max(0.5, seg["end"] - seg["start"])
            word_dur = duration / max(1, len(words))
            words_list = []
            cur_time = seg["start"]
            for w in words:
                words_list.append({
                    "word": w,
                    "start": round(cur_time, 2),
                    "end": round(min(seg["end"], cur_time + word_dur), 2)
                })
                cur_time += word_dur
            new_segments.append({
                "start": seg["start"],
                "end": seg["end"],
                "text": line,
                "words": words_list
            })
        return {"status": "success", "lyrics": new_segments}

    new_segments = []
    used_indices = set()
    
    for line_idx, line in enumerate(lines):
        candidates = [t for i, t in enumerate(orig_texts) if i not in used_indices]
        match = difflib.get_close_matches(line, candidates, n=1, cutoff=0.18)
        
        if match:
            orig_idx = orig_texts.index(match[0])
            used_indices.add(orig_idx)
            seg = original_segments[orig_idx]
            start_t = seg["start"]
            end_t = seg["end"]
        else:
            ratio = line_idx / max(1, len(lines) - 1)
            target_idx = min(len(original_segments) - 1, int(round(ratio * (len(original_segments) - 1))))
            seg = original_segments[target_idx]
            start_t = seg["start"]
            end_t = seg["end"]

        words = line.split()
        duration = max(0.5, end_t - start_t)
        word_dur = duration / max(1, len(words))
        words_list = []
        cur_time = start_t
        for w in words:
            words_list.append({
                "word": w,
                "start": round(cur_time, 2),
                "end": round(min(end_t, cur_time + word_dur), 2)
            })
            cur_time += word_dur

        new_segments.append({
            "start": round(start_t, 2),
            "end": round(end_t, 2),
            "text": line,
            "words": words_list
        })
        
    new_segments.sort(key=lambda x: x["start"])
    # Persistir inmediatamente el archivo alineado en disco
    try:
        with open(lyrics_path, "w", encoding="utf-8") as f:
            json.dump(new_segments, f, ensure_ascii=False, indent=2)
        from app.subtitles import generate_srt, generate_vtt
        with open(os.path.join(OUTPUT_DIR, f"{job_id}_lyrics.srt"), "w", encoding="utf-8") as f:
            f.write(generate_srt(new_segments))
        with open(os.path.join(OUTPUT_DIR, f"{job_id}_lyrics.vtt"), "w", encoding="utf-8") as f:
            f.write(generate_vtt(new_segments))
    except Exception as se:
        logger.error(f"Error guardando lyrics alineadas en disco para {job_id}: {se}")
        
    return {"status": "success", "lyrics": new_segments}

# Endpoint para generar el video de Karaoke sincronizado personalizado (Fase 5)
@app.post("/api/generate-video")
async def generate_video_endpoint(
    job_id: str = Form(...),
    aspect_ratio: str = Form("16:9"),
    font_name: str = Form("Arial"),
    active_color: str = Form("#FF0000"),
    inactive_color: str = Form("#FFFF00"),
    background_file: UploadFile = File(None),
    lyrics_data: str = Form(None),
    vocals_volume: float = Form(0.0)
):
    # Cargar trabajo en memoria desde el archivo de estado de disco si se reinició el servidor
    if job_id not in jobs_status:
        status_path = os.path.join(OUTPUT_DIR, f"{job_id}_status.json")
        if os.path.exists(status_path):
            try:
                with open(status_path, "r", encoding="utf-8") as f:
                    jobs_status[job_id] = json.load(f)
            except Exception as e:
                logger.error(f"Error al cargar estado de {job_id} para generación de video: {e}")
                
    # Guardar las letras actualizadas/editadas si son provistas por el cliente
    if lyrics_data:
        try:
            parsed_lyrics = json.loads(lyrics_data)
            
            # Sincronizar palabras y duraciones para cada segmento con el texto editado
            for seg in parsed_lyrics:
                text_content = seg.get("text", "").strip()
                words_list = text_content.split()
                existing_words = seg.get("words", [])
                
                # Si las palabras no coinciden exactamente con el texto editado, reconstruirlas
                if not existing_words or len(existing_words) != len(words_list) or [w.get("word") for w in existing_words] != words_list:
                    duration = max(0.4, float(seg.get("end", 0)) - float(seg.get("start", 0)))
                    word_dur = duration / max(1, len(words_list))
                    cur_t = float(seg.get("start", 0))
                    rebuilt_words = []
                    for w in words_list:
                        rebuilt_words.append({
                            "word": w,
                            "start": round(cur_t, 2),
                            "end": round(min(float(seg.get("end", 0)), cur_t + word_dur), 2)
                        })
                        cur_t += word_dur
                    seg["words"] = rebuilt_words
            
            # Guardar el JSON actualizado
            lyrics_filename = f"{job_id}_lyrics.json"
            lyrics_path = os.path.join(OUTPUT_DIR, lyrics_filename)
            with open(lyrics_path, "w", encoding="utf-8") as f:
                json.dump(parsed_lyrics, f, ensure_ascii=False, indent=2)
                
            # Regenerar subtítulos SRT y VTT basados en la edición
            from app.subtitles import generate_srt, generate_vtt
            srt_filename = f"{job_id}_lyrics.srt"
            srt_path = os.path.join(OUTPUT_DIR, srt_filename)
            with open(srt_path, "w", encoding="utf-8") as f:
                f.write(generate_srt(parsed_lyrics))
                
            vtt_filename = f"{job_id}_lyrics.vtt"
            vtt_path = os.path.join(OUTPUT_DIR, vtt_filename)
            with open(vtt_path, "w", encoding="utf-8") as f:
                f.write(generate_vtt(parsed_lyrics))
                
            # Actualizar en memoria
            if job_id in jobs_status:
                jobs_status[job_id]["lyrics"] = lyrics_filename
                jobs_status[job_id]["srt"] = srt_filename
                jobs_status[job_id]["vtt"] = vtt_filename
                
        except Exception as le:
            logger.error(f"Error procesando edición de letras para {job_id}: {str(le)}")
            raise HTTPException(status_code=400, detail=f"Datos de letra inválidos: {str(le)}")

    background_filename = None
    if background_file and background_file.filename:
        # Validar extensión del fondo
        allowed_bg_extensions = {".jpg", ".jpeg", ".png", ".webp", ".mp4", ".mov", ".avi", ".mkv"}
        bg_ext = os.path.splitext(background_file.filename)[1].lower()
        if bg_ext not in allowed_bg_extensions:
            raise HTTPException(
                status_code=400,
                detail=f"Formato de fondo no soportado. Formatos válidos: {', '.join(allowed_bg_extensions)}"
            )
        
        # Guardar el archivo de fondo en la carpeta de outputs
        background_filename = f"{job_id}_bg{bg_ext}"
        bg_path = os.path.join(OUTPUT_DIR, background_filename)
        
        try:
            with open(bg_path, "wb") as buffer:
                content = await background_file.read()
                buffer.write(content)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"No se pudo guardar el archivo de fondo: {str(e)}")
            
    from app.video_renderer import start_video_generation
    success = start_video_generation(
        job_id,
        aspect_ratio=aspect_ratio,
        font_name=font_name,
        active_color=active_color,
        inactive_color=inactive_color,
        background_filename=background_filename,
        vocals_volume=vocals_volume
    )
    
    if not success:
        raise HTTPException(
            status_code=400,
            detail="No se pudo iniciar el proceso de renderizado del video Karaoke. Verifique los archivos."
        )
    return {"status": "rendering"}

# Servir el frontend Web Studio oficial de DiviVoice en la raíz
static_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "static"))
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")

@app.get("/")
def read_root():
    static_index = os.path.join(static_dir, "index.html")
    if os.path.exists(static_index):
        return FileResponse(static_index)
    return {"message": "Servidor DiviVoice activo. Frontend no encontrado."}

# Servir la aplicación Flutter Web compilada opcionalmente en /flutter
flutter_web_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "frontend_flutter", "build", "web"))
if os.path.exists(flutter_web_dir):
    app.mount("/flutter", StaticFiles(directory=flutter_web_dir, html=True), name="flutter_web_app")
