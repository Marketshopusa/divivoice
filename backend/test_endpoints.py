import requests
import json
import time

BASE_URL = "http://localhost:8005"

def run_tests():
    print("--- INICIANDO VERIFICACIÓN DE ENDPOINTS DIVIVOICE ---")
    
    # Esperar a que el servidor inicialice completamente
    time.sleep(2)
    
    # 1. Test Registro
    print("\n1. Registrando nuevo usuario de prueba...")
    reg_payload = {
        "username": "testuser",
        "email": "testuser@divivoice.com",
        "password": "securepassword123"
    }
    try:
        r = requests.post(f"{BASE_URL}/api/auth/register", json=reg_payload)
        print(f"Status Code: {r.statusCode if hasattr(r, 'statusCode') else r.status_code}")
        print(f"Respuesta: {r.text}")
    except Exception as e:
        print(f"Error al registrar: {e}")

    # 2. Test Login
    print("\n2. Iniciando sesión...")
    login_payload = {
        "email_or_username": "testuser",
        "password": "securepassword123"
    }
    token = None
    try:
        r = requests.post(f"{BASE_URL}/api/auth/login", json=login_payload)
        print(f"Status Code: {r.status_code}")
        if r.status_code == 200:
            token = r.json().get("access_token")
            print("Token obtenido con éxito.")
        else:
            print(f"Fallo de Login: {r.text}")
    except Exception as e:
        print(f"Error al iniciar sesión: {e}")

    if not token:
        print("\nPruebas canceladas: no se pudo obtener el token JWT.")
        return

    headers = {"Authorization": f"Bearer {token}"}

    # 3. Test Obtener Usuario Actual
    print("\n3. Obteniendo información de perfil (/me)...")
    try:
        r = requests.get(f"{BASE_URL}/api/auth/me", headers=headers)
        print(f"Status Code: {r.status_code}")
        print(f"Respuesta: {r.text}")
    except Exception as e:
        print(f"Error al obtener perfil: {e}")

    # 4. Test Obtener Catálogo de Canciones
    print("\n4. Consultando catálogo de canciones para cantar...")
    try:
        r = requests.get(f"{BASE_URL}/api/social/songs", headers=headers)
        print(f"Status Code: {r.status_code}")
        print(f"Respuesta: {r.text}")
    except Exception as e:
        print(f"Error al consultar catálogo: {e}")

    # 5. Test Listar Salas Activas
    print("\n5. Consultando salas de fiesta activas...")
    try:
        r = requests.get(f"{BASE_URL}/api/rooms/", headers=headers)
        print(f"Status Code: {r.status_code}")
        print(f"Respuesta: {r.text}")
    except Exception as e:
        print(f"Error al consultar salas: {e}")

if __name__ == "__main__":
    run_tests()
