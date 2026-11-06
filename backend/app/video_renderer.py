import os
import subprocess
import threading
import logging
import json
from app.config import OUTPUT_DIR, LOGO_DIR
from app.ass_generator import generate_ass

logger = logging.getLogger("divivoice-video")

def run_ffmpeg_render(
    job_id: str,
    aspect_ratio: str,
    instrumental_filename: str,
    ass_filename: str,
    output_video_filename: str,
    background_filename: str = None,
    vocals_filename: str = None,
    vocals_volume: float = 0.0
):
    """
    Ejecuta el renderizado de FFmpeg aplicando las escalas del fondo personalizado
    y quemando los subtítulos ASS sobre la pista de audio instrumental.
    Admite mezcla de voz guía (vocals_volume > 0) y marca de agua en movimiento del logotipo.
    Si no se especifica fondo, se usa el logotipo de DiviVoice de forma predeterminada.
    """
    try:
        logger.info(f"Iniciando renderizado FFmpeg para {job_id} ({aspect_ratio}). Fondo: {background_filename or 'Logotipo Predeterminado'}, Voz guía: {vocals_volume:.2f}")
        
        # Determinar resoluciones
        if aspect_ratio == "16:9":
            resolution = "1280x720"
            width, height = 1280, 720
        elif aspect_ratio == "9:16":
            resolution = "720x1280"
            width, height = 720, 1280
        else: # "1:1"
            resolution = "800x800"
            width, height = 800, 800
            
        cmd = ["ffmpeg", "-y"]
        
        # Resolver fondo predeterminado si no se subió uno
        use_default_logo = False
        default_logo_path = os.path.join(LOGO_DIR, "logo.jpg")
        
        if not background_filename:
            for f in os.listdir(OUTPUT_DIR):
                if f.startswith(f"{job_id}_bg."):
                    background_filename = f
                    break

        if not background_filename or not os.path.exists(os.path.join(OUTPUT_DIR, background_filename)):
            if os.path.exists(default_logo_path):
                background_filename = default_logo_path
                use_default_logo = True
        else:
            # Si es personalizado, asegurar ruta absoluta para el directorio de ejecución
            background_filename = os.path.join(OUTPUT_DIR, background_filename)

        # 1. Configurar entradas de fondo
        is_video = False
        if background_filename and os.path.exists(background_filename):
            ext = os.path.splitext(background_filename)[1].lower()
            is_video = ext in {".mp4", ".mov", ".avi", ".mkv", ".m4v"}
            
            if is_video:
                # Entrada de video bucleada infinitamente
                cmd.extend(["-stream_loop", "-1", "-i", background_filename])
            else:
                # Entrada de imagen estática bucleada
                cmd.extend(["-loop", "1", "-i", background_filename])
        else:
            # Color sólido de fondo si nada más está disponible
            background_color = "0xFAFAFA"
            cmd.extend(["-f", "lavfi", "-i", f"color=c={background_color}:s={resolution}:r=25"])
            
        # Entrada 1: Pista de audio instrumental
        cmd.extend(["-i", instrumental_filename])
        
        # Entrada 2 (opcional): Pista de voces (voz guía)
        mix_vocals = vocals_filename and os.path.exists(os.path.join(OUTPUT_DIR, vocals_filename)) and vocals_volume > 0.0
        if mix_vocals:
            cmd.extend(["-i", vocals_filename])
            
        # Entrada 3 (o 2 si no hay voz guía): Logotipo para marca de agua en movimiento
        show_watermark = os.path.exists(default_logo_path)
        if show_watermark:
            cmd.extend(["-loop", "1", "-i", default_logo_path])
            watermark_index = 3 if mix_vocals else 2

        # 2. Construir filter_complex
        filter_complex_parts = []
        
        # Configurar filtro para el fondo (0:v)
        if use_default_logo:
            # Escalar y rellenar con fondo blanco para que encaje el logo perfectamente
            bg_filter = f"[0:v]scale={width}:{height}:force_original_aspect_ratio=decrease,pad={width}:{height}:(ow-iw)/2:(oh-ih)/2:color=white[bg]"
        elif background_filename and os.path.exists(background_filename):
            bg_filter = f"[0:v]scale={width}:{height}:force_original_aspect_ratio=increase,crop={width}:{height}[bg]"
        else:
            bg_filter = "[0:v]null[bg]"
            
        filter_complex_parts.append(bg_filter)
        
        # Configurar filtro para marca de agua en movimiento y overlay
        if show_watermark:
            # Escalar logo a 140px de ancho (divisible por 2 usando -2) y darle 25% de opacidad (aa=0.25)
            wm_filter = f"[{watermark_index}:v]scale=140:-2,format=rgba,colorchannelmixer=aa=0.25[wm]"
            # Curva de Lissajous suave para mover la marca de agua en movimiento continuo por la pantalla
            overlay_filter = f"[bg][wm]overlay=x='(W-w)/2+((W-w)/2)*sin(t*0.4)':y='(H-h)/2+((H-h)/2)*cos(t*0.6)':eval=frame:shortest=1[bg_wm]"
            # Forzar resolución final exacta de salida mediante escala para evitar problemas de anchos impares (libx264 error)
            subtitles_filter = f"[bg_wm]ass={ass_filename},scale={width}:{height}[outv]"
            
            filter_complex_parts.append(wm_filter)
            filter_complex_parts.append(overlay_filter)
            filter_complex_parts.append(subtitles_filter)
        else:
            filter_complex_parts.append(f"[bg]ass={ass_filename},scale={width}:{height}[outv]")
            
        # Configurar filtro para mezcla de audio (voz guía)
        if mix_vocals:
            filter_complex_parts.append(f"[1:a]volume=1.0[a1]; [2:a]volume={vocals_volume:.2f}[a2]; [a1][a2]amix=inputs=2:duration=first[aout]")
            
        cmd.extend(["-filter_complex", "; ".join(filter_complex_parts)])
        
        # Mapear las salidas resultantes
        cmd.extend(["-map", "[outv]"])
        if mix_vocals:
            cmd.extend(["-map", "[aout]"])
        else:
            cmd.extend(["-map", "1:a"])
            
        # Configurar salida y códecs
        cmd.extend([
            "-c:v", "libx264", "-preset", "ultrafast",
            "-pix_fmt", "yuv420p",
            "-movflags", "+faststart",
            "-c:a", "aac",
            "-shortest",
            output_video_filename
        ])
        
        logger.info(f"Ejecutando comando FFmpeg: {' '.join(cmd)}")
        
        # Ejecutar en el directorio OUTPUT_DIR para asegurar rutas cortas y relativas
        result = subprocess.run(
            cmd,
            cwd=str(OUTPUT_DIR),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        if result.returncode == 0:
            logger.info(f"Video Karaoke generado correctamente para {job_id}")
            from app.separator import jobs_status, save_job_status
            if job_id in jobs_status:
                jobs_status[job_id]["video_status"] = "completed"
                jobs_status[job_id]["video_file"] = output_video_filename
                save_job_status(job_id)
        else:
            logger.error(f"FFmpeg falló. Stderr: {result.stderr}")
            raise Exception(f"FFmpeg falló al renderizar el video: {result.stderr}")
            
    except Exception as e:
        logger.error(f"Error renderizando video para {job_id}: {str(e)}")
        from app.separator import jobs_status, save_job_status
        if job_id in jobs_status:
            jobs_status[job_id]["video_status"] = "failed"
            jobs_status[job_id]["video_error"] = str(e)
            save_job_status(job_id)

def start_video_generation(
    job_id: str,
    aspect_ratio: str = "16:9",
    font_name: str = "Arial",
    active_color: str = "#FF0000",
    inactive_color: str = "#FFFF00",
    background_filename: str = None,
    vocals_volume: float = 0.0
) -> bool:
    """
    Prepara la sincronización ASS con las fuentes/colores y lanza el hilo de renderizado del video.
    """
    from app.separator import jobs_status
    
    if job_id not in jobs_status:
        status_path = os.path.join(OUTPUT_DIR, f"{job_id}_status.json")
        if os.path.exists(status_path):
            try:
                with open(status_path, "r", encoding="utf-8") as f:
                    jobs_status[job_id] = json.load(f)
            except Exception as e:
                logger.error(f"Error cargando status de {job_id}: {e}")

    if job_id not in jobs_status:
        logger.error(f"Trabajo {job_id} no encontrado en memoria ni en disco.")
        return False
        
    job = jobs_status[job_id]
    output_files = job.get("files", [])
    lyrics_filename = job.get("lyrics")
    
    # Encontrar la pista instrumental y la de voces
    instrumental_filename = next((f for f in output_files if "(Instrumental)" in f), None)
    if not instrumental_filename:
        for f in os.listdir(OUTPUT_DIR):
            if f.startswith(job_id) and "(Instrumental)" in f:
                instrumental_filename = f
                break

    vocals_filename = next((f for f in output_files if "(Vocals)" in f), None)
    if not vocals_filename:
        for f in os.listdir(OUTPUT_DIR):
            if f.startswith(job_id) and "(Vocals)" in f:
                vocals_filename = f
                break

    if not lyrics_filename:
        cand_lyrics = f"{job_id}_lyrics.json"
        if os.path.exists(os.path.join(OUTPUT_DIR, cand_lyrics)):
            lyrics_filename = cand_lyrics

    if not background_filename:
        background_filename = job.get("background_file")
    if not background_filename:
        for f in os.listdir(OUTPUT_DIR):
            if f.startswith(f"{job_id}_bg."):
                background_filename = f
                break
    
    if not instrumental_filename or not lyrics_filename:
        logger.error(f"Archivos necesarios no encontrados para {job_id} (Inst: {instrumental_filename}, Lyrics: {lyrics_filename})")
        return False
        
    try:
        # Cargar las marcas de tiempo JSON
        lyrics_path = os.path.join(OUTPUT_DIR, lyrics_filename)
        with open(lyrics_path, "r", encoding="utf-8") as f:
            lyrics_data = json.load(f)
            
        # Generar archivo ASS personalizado
        ass_content = generate_ass(
            lyrics_data,
            aspect_ratio=aspect_ratio,
            font_name=font_name,
            active_color=active_color,
            inactive_color=inactive_color
        )
        ass_filename = f"{job_id}_lyrics.ass"
        ass_path = os.path.join(OUTPUT_DIR, ass_filename)
        with open(ass_path, "w", encoding="utf-8") as f:
            f.write(ass_content)
            
        output_video_filename = f"{job_id}_karaoke.mp4"
        
        # Registrar estados
        job["video_status"] = "rendering"
        job["video_file"] = None
        job["video_error"] = None
        
        # Guardar estilos y aspecto para que persistan en el cliente
        job["aspect_ratio"] = aspect_ratio
        job["font_name"] = font_name
        job["active_color"] = active_color
        job["inactive_color"] = inactive_color
        job["vocals_volume"] = vocals_volume
        if background_filename:
            job["background_file"] = background_filename
            
        from app.separator import save_job_status
        save_job_status(job_id)
        
        # Lanzar el hilo de renderizado asíncrono
        thread = threading.Thread(
            target=run_ffmpeg_render,
            args=(job_id, aspect_ratio, instrumental_filename, ass_filename, output_video_filename, background_filename, vocals_filename, vocals_volume),
            daemon=True
        )
        thread.start()
        return True
        
    except Exception as e:
        logger.error(f"No se pudo iniciar la generación del video para {job_id}: {str(e)}")
        job["video_status"] = "failed"
        job["video_error"] = str(e)
        return False
