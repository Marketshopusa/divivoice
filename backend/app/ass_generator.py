def format_ass_time(seconds: float) -> str:
    """
    Formatea segundos flotantes en formato HH:MM:SS.cs (centisegundos) requerido por ASS.
    """
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    centiseconds = int(round((seconds - int(seconds)) * 100))
    
    # Manejar desbordamientos de redondeo
    if centiseconds >= 100:
        centiseconds = 0
        secs += 1
    if secs >= 60:
        secs = 0
        minutes += 1
    if minutes >= 60:
        minutes = 0
        hours += 1
        
    return f"{hours}:{minutes:02d}:{secs:02d}.{centiseconds:02d}"

def hex_to_ass_color(hex_str: str, default: str = "&H00FFFFFF") -> str:
    """
    Convierte colores hexadecimales estándar (#RRGGBB) a formato ASS (&H00BBGGRR).
    """
    if not hex_str:
        return default
    hex_str = hex_str.lstrip('#').strip()
    if len(hex_str) == 6:
        r = hex_str[0:2]
        g = hex_str[2:4]
        b = hex_str[4:6]
        return f"&H00{b}{g}{r}"
    elif len(hex_str) == 3:
        r = hex_str[0]*2
        g = hex_str[1]*2
        b = hex_str[2]*2
        return f"&H00{b}{g}{r}"
    return default

def generate_ass(
    segments: list,
    aspect_ratio: str = "16:9",
    font_name: str = "Arial",
    active_color: str = "#FF0000",
    inactive_color: str = "#FFFF00"
) -> str:
    """
    Genera el contenido de un archivo de subtítulos ASS optimizado para Karaoke.
    Permite personalizar fuentes, colores (activo/inactivo) y formatos de pantalla.
    """
    # Resoluciones: 16:9 -> 1280x720, 9:16 -> 720x1280, 1:1 -> 800x800
    if aspect_ratio == "16:9":
        width, height = 1280, 720
        fontsize = 52  # Incrementado de 36
        margin_v = 80
        max_words_per_line = 6
    elif aspect_ratio == "9:16":
        width, height = 720, 1280
        fontsize = 38  # Incrementado de 28
        margin_v = 300
        max_words_per_line = 4
    else:  # "1:1"
        width, height = 800, 800
        fontsize = 44  # Incrementado de 32
        margin_v = 150
        max_words_per_line = 5
        
    # Convertir colores Hex a formato ASS
    # Active color (Primary)
    primary_color_ass = hex_to_ass_color(active_color, "&H000000FF") # Default Rojo
    # Inactive color (Secondary)
    secondary_color_ass = hex_to_ass_color(inactive_color, "&H0000FFFF") # Default Amarillo
    
    ass_lines = [
        "[Script Info]",
        "ScriptType: v4.00+",
        f"PlayResX: {width}",
        f"PlayResY: {height}",
        "WrapStyle: 0",
        "",
        "[V4+ Styles]",
        "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding",
        # PrimaryColour = Color de letra activa (canto)
        # SecondaryColour = Color de letra inactiva (espera)
        # Outline = Negro (&H00000000), Shadow = Gris translúcido
        f"Style: Default,{font_name},{fontsize},{primary_color_ass},{secondary_color_ass},&H00000000,&H00111111,-1,0,0,0,100,100,0,0,1,3,1,2,40,40,{margin_v},1",
        "",
        "[Events]",
        "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"
    ]
    
    for seg in segments:
        start_str = format_ass_time(seg["start"])
        end_str = format_ass_time(seg["end"])
        
        # Generar etiquetas de karaoke palabra por palabra \k
        text_parts = []
        last_time = seg["start"]
        
        words = seg.get("words", [])
        text_words = seg.get("text", "").strip().split()
        if text_words and (not words or len(words) != len(text_words) or [w.get("word") for w in words] != text_words):
            duration = max(0.4, seg["end"] - seg["start"])
            word_dur = duration / max(1, len(text_words))
            words = []
            cur_t = seg["start"]
            for tw in text_words:
                words.append({
                    "word": tw,
                    "start": round(cur_t, 2),
                    "end": round(min(seg["end"], cur_t + word_dur), 2)
                })
                cur_t += word_dur
        
        # Si la frase contiene más palabras que el límite horizontal del formato,
        # calculamos los índices óptimos para insertar saltos de línea (\N)
        break_indices = set()
        if len(words) > max_words_per_line:
            num_lines = (len(words) + max_words_per_line - 1) // max_words_per_line
            words_per_line = (len(words) + num_lines - 1) // num_lines
            for i in range(1, num_lines):
                break_indices.add(i * words_per_line)
        
        for idx, w in enumerate(words):
            w_start = w["start"]
            w_end = w["end"]
            w_text = w["word"]
            
            # Si hay un espacio de silencio entre palabras, agregarlo con una etiqueta de tiempo vacía
            gap = int(round((w_start - last_time) * 100))
            if gap > 0:
                text_parts.append(f"{{\\k{gap}}}")
                
            duration = int(round((w_end - w_start) * 100))
            if duration <= 0:
                duration = 1  # Evitar duración 0
                
            # Insertar el salto de línea si corresponde
            line_break = "\\N" if idx in break_indices else ""
            
            # Formatear la palabra en ASS. Si sigue a un salto de línea omitimos espacio para evitar desalineación.
            text_parts.append(f"{line_break}{{\\k{duration}}}{w_text} ")
            last_time = w_end
            
        ass_text = "".join(text_parts).strip()
        if not ass_text:
            # Fallback a texto plano si no hay desglose por palabras
            ass_text = seg["text"]
            
        # Añadir diálogo al archivo ASS
        ass_lines.append(f"Dialogue: 0,{start_str},{end_str},Default,,0,0,0,,{ass_text}")
        
    return "\n".join(ass_lines)
