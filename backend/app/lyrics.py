import os
import logging
from faster_whisper import WhisperModel

logger = logging.getLogger("divivoice-lyrics")

# Diccionario para almacenar instancias de modelos según su tamaño
_model_instances = {}

def get_whisper_model(model_size: str = "small"):
    global _model_instances
    # Asegurar que el tamaño del modelo sea válido
    valid_sizes = {"tiny", "base", "small", "medium"}
    if model_size not in valid_sizes:
        model_size = "small"
        
    if model_size not in _model_instances:
        logger.info(f"Cargando modelo Whisper ({model_size}) en CPU...")
        # int8 es óptimo para ejecución rápida en CPU con menor consumo de RAM
        _model_instances[model_size] = WhisperModel(model_size, device="cpu", compute_type="int8")
        logger.info(f"Modelo Whisper ({model_size}) cargado con éxito.")
    return _model_instances[model_size]

def extract_lyrics(audio_path: str, model_size: str = "small", language: str = None) -> list:
    """
    Transcribe el audio vocal usando el modelo seleccionado e incorporando 
    filtro VAD y selector de idioma para evitar errores de alucinación y transcripción.
    """
    try:
        model = get_whisper_model(model_size)
        logger.info(f"Iniciando transcripción (Modelo: {model_size}, Idioma: {language or 'Auto'}) para: {audio_path}")
        
        # Si el idioma es "auto", lo pasamos como None para auto-detección
        transcribe_lang = None if language == "auto" or not language else language
        
        # Ejecutar transcripción:
        # - word_timestamps=True habilita el tracking palabra por palabra
        # - vad_filter=True filtra silencios y partes puramente instrumentales para evitar alucinaciones
        segments, info = model.transcribe(
            audio_path,
            word_timestamps=True,
            beam_size=5,
            language=transcribe_lang,
            vad_filter=True,
            vad_parameters=dict(min_silence_duration_ms=500)
        )
        
        logger.info(f"Idioma detectado: {info.language} (Probabilidad: {info.language_probability:.2f})")
        
        lyrics_data = []
        for segment in segments:
            words_list = []
            if segment.words:
                for w in segment.words:
                    words_list.append({
                        "word": w.word.strip(),
                        "start": round(w.start, 2),
                        "end": round(w.end, 2)
                    })
            
            lyrics_data.append({
                "start": round(segment.start, 2),
                "end": round(segment.end, 2),
                "text": segment.text.strip(),
                "words": words_list
            })
            
        logger.info(f"Transcripción finalizada. {len(lyrics_data)} líneas generadas.")
        return lyrics_data
    except Exception as e:
        logger.error(f"Error extrayendo letra: {str(e)}", exc_info=True)
        raise e
