from app.database import SessionLocal
from app.models import Gift

def seed_initial_data():
    """
    Inicializa únicamente los catálogos del sistema (como los regalos virtuales oficiales de DiviVoice).
    No crea usuarios ficticios, salas falsas ni canciones inventadas.
    La plataforma inicia limpia para usuarios reales.
    """
    db = SessionLocal()
    try:
        if db.query(Gift).count() == 0:
            gifts_data = [
                Gift(name="Rosa Musical", icon="fa-solid fa-wand-magic-sparkles", price=10, animation="pop", category="popular"),
                Gift(name="Micrófono Dorado", icon="fa-solid fa-microphone-lines", price=50, animation="pop", category="popular"),
                Gift(name="Corona Real", icon="fa-solid fa-crown", price=200, animation="crown", category="vip"),
                Gift(name="Guitarra de Fuego", icon="fa-solid fa-guitar", price=500, animation="fire", category="vip"),
                Gift(name="Disco de Platino", icon="fa-solid fa-compact-disc", price=300, animation="pop", category="concert"),
                Gift(name="Cohete Estelar", icon="fa-solid fa-rocket", price=1000, animation="fire", category="concert"),
            ]
            db.add_all(gifts_data)
            db.commit()
            print("Catálogo de regalos oficiales de DiviVoice inicializado correctamente.")
    except Exception as e:
        db.rollback()
        print(f"Error al inicializar catálogo de regalos: {e}")
    finally:
        db.close()
