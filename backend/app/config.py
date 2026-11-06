import os
from pathlib import Path

# Directorios base del proyecto
BASE_DIR = Path(__file__).resolve().parent.parent
UPLOAD_DIR = BASE_DIR / "uploads"
OUTPUT_DIR = BASE_DIR / "outputs"
LOGO_DIR = BASE_DIR.parent / "logo"

# Crear directorios si no existen
os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(LOGO_DIR, exist_ok=True)

# Configuración de los modelos de IA
# El modelo por defecto es Kim_Vocal_2 (excelente calidad de separación voz/instrumental)
DEFAULT_MODEL = "Kim_Vocal_2.onnx"
