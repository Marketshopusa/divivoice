import os
import logging
import numpy as np
import librosa
import mido
from mido import MidiFile, MidiTrack, Message, MetaMessage

logger = logging.getLogger("divivoice-midi")

def generate_midi_from_audio(audio_path: str, output_midi_path: str, lyrics_data: list = None, bpm: int = 120):
    """
    Convierte la pista vocal o melodía de un audio en un archivo MIDI estándar (.mid).
    Incluye transcripción de notas por pitch detection (pYIN) y fallback armónico sincronizado
    con las letras.
    """
    mid = MidiFile(ticks_per_beat=480)
    track = MidiTrack()
    mid.tracks.append(track)

    # Configuración de Tempo (120 BPM por defecto => 500,000 microsegundos por beat)
    tempo = mido.bpm2tempo(bpm)
    track.append(MetaMessage('set_tempo', tempo=tempo, time=0))
    track.append(MetaMessage('track_name', name='Melody / Vocal Lead', time=0))
    track.append(Message('program_change', program=0, time=0)) # Acoustic Grand Piano / Synth Lead

    ticks_per_second = (mid.ticks_per_beat * bpm) / 60.0

    notes_detected = []
    
    # Intentar extracción acústica con librosa
    if audio_path and os.path.exists(audio_path):
        try:
            logger.info(f"Analizando frecuencias de audio para transcripción MIDI: {audio_path}")
            # Cargar a 16kHz o 22kHz para procesamiento rápido
            y, sr = librosa.load(audio_path, sr=22050, mono=True)
            
            # Limitar duración a primeros 10 minutos para evitar demoras
            max_samples = 22050 * 600
            if len(y) > max_samples:
                y = y[:max_samples]

            hop_length = 1024
            frame_duration = hop_length / sr

            # Extracción f0 con pYIN optimizado
            fmin = librosa.note_to_hz('C2')
            fmax = librosa.note_to_hz('C7')
            f0, voiced_flag, voiced_probs = librosa.pyin(y, fmin=fmin, fmax=fmax, sr=sr, hop_length=hop_length)

            current_note = None
            start_frame = 0

            for i in range(len(f0)):
                is_voiced = voiced_flag[i] and not np.isnan(f0[i]) and f0[i] > 0
                if is_voiced:
                    midi_val = int(np.clip(np.round(librosa.hz_to_midi(f0[i])), 24, 108))
                    if current_note is None:
                        current_note = midi_val
                        start_frame = i
                    elif abs(midi_val - current_note) >= 1: # Cambio de nota
                        dur_sec = (i - start_frame) * frame_duration
                        if dur_sec >= 0.08: # Mínimo 80ms para evitar jitter
                            start_sec = start_frame * frame_duration
                            notes_detected.append({
                                "note": current_note,
                                "start": start_sec,
                                "duration": dur_sec,
                                "velocity": 85
                            })
                        current_note = midi_val
                        start_frame = i
                else:
                    if current_note is not None:
                        dur_sec = (i - start_frame) * frame_duration
                        if dur_sec >= 0.08:
                            start_sec = start_frame * frame_duration
                            notes_detected.append({
                                "note": current_note,
                                "start": start_sec,
                                "duration": dur_sec,
                                "velocity": 85
                            })
                        current_note = None

            logger.info(f"Detección acústica completada: {len(notes_detected)} notas extraídas.")
        except Exception as e:
            logger.warning(f"Aviso en detección acústica de notas ({e}). Usando generador armónico sincronizado.")

    # Si no se detectaron notas acústicas o el audio era puramente silencioso, generar usando timestamps de letras
    if len(notes_detected) < 5 and lyrics_data and len(lyrics_data) > 0:
        logger.info("Generando notas MIDI a partir de la métrica de letras sincronizadas...")
        scale_c_major = [60, 62, 64, 65, 67, 69, 71, 72] # Do, Re, Mi, Fa, Sol, La, Si, Do
        note_idx = 0
        for segment in lyrics_data:
            start = float(segment.get("start", 0.0))
            end = float(segment.get("end", start + 0.5))
            dur = max(0.2, end - start)
            
            # Si tiene palabras detalladas
            words = segment.get("words", [])
            if words and len(words) > 0:
                for w in words:
                    w_start = float(w.get("start", start))
                    w_end = float(w.get("end", w_start + 0.3))
                    w_dur = max(0.15, w_end - w_start)
                    notes_detected.append({
                        "note": scale_c_major[note_idx % len(scale_c_major)],
                        "start": w_start,
                        "duration": w_dur,
                        "velocity": 90,
                        "lyric": w.get("word", "")
                    })
                    note_idx += 1
            else:
                notes_detected.append({
                    "note": scale_c_major[note_idx % len(scale_c_major)],
                    "start": start,
                    "duration": dur,
                    "velocity": 90,
                    "lyric": segment.get("text", "")
                })
                note_idx += 1

    # Si sigue vacío (caso extremo), crear arpegio de bienvenida
    if len(notes_detected) == 0:
        base_time = 0.5
        for n in [60, 64, 67, 72, 67, 64, 60]:
            notes_detected.append({
                "note": n,
                "start": base_time,
                "duration": 0.4,
                "velocity": 80
            })
            base_time += 0.5

    # Ordenar eventos cronológicamente
    events = []
    for item in notes_detected:
        start_tick = int(item["start"] * ticks_per_second)
        end_tick = start_tick + max(1, int(item["duration"] * ticks_per_second))
        lyric = item.get("lyric", None)
        events.append((start_tick, "on", item["note"], item.get("velocity", 85), lyric))
        events.append((end_tick, "off", item["note"], 0, None))

    events.sort(key=lambda x: (x[0], 0 if x[1] == "off" else 1))

    current_tick = 0
    for tick, event_type, note, vel, lyric in events:
        delta = max(0, tick - current_tick)
        current_tick = tick
        
        if lyric:
            track.append(MetaMessage('lyrics', text=lyric, time=0))
            
        if event_type == "on":
            track.append(Message('note_on', note=note, velocity=vel, time=delta))
        else:
            track.append(Message('note_off', note=note, velocity=0, time=delta))

    # Fin de pista
    track.append(MetaMessage('end_of_track', time=480))
    mid.save(output_midi_path)
    logger.info(f"Archivo MIDI exportado exitosamente en: {output_midi_path}")
    return output_midi_path
