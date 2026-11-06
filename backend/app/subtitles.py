def format_time(seconds: float, separator: str = ",") -> str:
    """
    Formatea segundos flotantes en formato de tiempo de subtítulos HH:MM:SS,mmm o HH:MM:SS.mmm
    """
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    milliseconds = int(round((seconds - int(seconds)) * 1000))
    
    # Manejar desbordamientos de redondeo
    if milliseconds >= 1000:
        milliseconds = 0
        secs += 1
    if secs >= 60:
        secs = 0
        minutes += 1
    if minutes >= 60:
        minutes = 0
        hours += 1
        
    return f"{hours:02d}:{minutes:02d}:{secs:02d}{separator}{milliseconds:03d}"

def generate_srt(segments: list) -> str:
    """
    Genera una cadena de texto en formato SRT a partir de los segmentos de Whisper.
    """
    srt_lines = []
    for idx, seg in enumerate(segments):
        start = format_time(seg["start"], ",")
        end = format_time(seg["end"], ",")
        text = seg["text"].strip()
        
        srt_lines.append(f"{idx + 1}")
        srt_lines.append(f"{start} --> {end}")
        srt_lines.append(text)
        srt_lines.append("")  # Espacio en blanco requerido entre subtítulos
        
    return "\n".join(srt_lines)

def generate_vtt(segments: list) -> str:
    """
    Genera una cadena de texto en formato WebVTT a partir de los segmentos de Whisper.
    """
    vtt_lines = ["WEBVTT", ""]
    for idx, seg in enumerate(segments):
        start = format_time(seg["start"], ".")
        end = format_time(seg["end"], ".")
        text = seg["text"].strip()
        
        vtt_lines.append(f"{idx + 1}")
        vtt_lines.append(f"{start} --> {end}")
        vtt_lines.append(text)
        vtt_lines.append("")
        
    return "\n".join(vtt_lines)

def format_lrc_time(seconds: float) -> str:
    """
    Formatea segundos en formato LRC estándar: [mm:ss.xx]
    """
    minutes = int(seconds // 60)
    secs = seconds % 60
    return f"[{minutes:02d}:{secs:05.2f}]"

def generate_lrc(segments: list, title: str = "", artist: str = "") -> str:
    """
    Genera contenido en formato LRC estándar para sincronización de letras en reproductores.
    """
    lrc_lines = []
    if title:
        lrc_lines.append(f"[ti:{title}]")
    if artist:
        lrc_lines.append(f"[ar:{artist}]")
    lrc_lines.append("[by:DiviVoice AI]")
    lrc_lines.append("")
    
    for seg in segments:
        time_tag = format_lrc_time(seg.get("start", 0.0))
        text = seg.get("text", "").strip()
        if text:
            lrc_lines.append(f"{time_tag}{text}")
            
    return "\n".join(lrc_lines)

