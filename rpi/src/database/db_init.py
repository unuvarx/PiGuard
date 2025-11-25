import sqlite3
import os

def init_db():
    current_dir = os.path.dirname(os.path.abspath(__file__))
    db_folder = os.path.join(current_dir, "../../data/db")
    db_path = os.path.join(db_folder, "registered_faces.db")

    if not os.path.exists(db_folder):
        os.makedirs(db_folder)

    conn = sqlite3.connect(db_path)
    c = conn.cursor()

    c.execute("""
        CREATE TABLE IF NOT EXISTS registered_faces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            image1 TEXT,
            image2 TEXT,
            image3 TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.commit()
    conn.close()
    print(f"Veritabanı başarıyla oluşturuldu: {db_path}")

if __name__ == "__main__":
    init_db()