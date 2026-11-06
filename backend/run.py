import uvicorn

if __name__ == "__main__":
    print("Iniciando DiviVoice API en http://localhost:8005")
    uvicorn.run("app.main:app", host="0.0.0.0", port=8005, reload=True)
