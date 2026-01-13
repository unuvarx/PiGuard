import os
import sqlite3

DATA_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'data'))
DB_DIR = os.path.join(DATA_DIR, 'db')
if not os.path.exists(DB_DIR):
    os.makedirs(DB_DIR, exist_ok=True)

DB_PATH = os.path.join(DB_DIR, 'PiGuardDB.db')

def init_db():
    """Initialize the PiGuardDB database and required tables."""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    c.execute('''
        CREATE TABLE IF NOT EXISTS registered_faces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            image1 TEXT,
            image2 TEXT,
            image3 TEXT,
            metadata TEXT,
            added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    c.execute('''
        CREATE TABLE IF NOT EXISTS strangers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT,
            metadata TEXT,
            added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    c.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stranger_id INTEGER,
            FOREIGN KEY (stranger_id) REFERENCES strangers(id)
        )
    ''')

    conn.commit()
    conn.close()
    print(f"Veritabanı başarıyla oluşturuldu: {DB_PATH}")

if __name__ == "__main__":
    init_db()