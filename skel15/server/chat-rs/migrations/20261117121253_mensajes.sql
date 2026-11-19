CREATE TABLE IF NOT EXISTS mensajes (
  id INTEGER PRIMARY KEY, -- INTEGER exacto: con INT el id no se autonumera
  -- shortcut: hora local, como la mostraba MySQL; si se despliega, guardar UTC
  instante TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  nick TEXT NOT NULL CHECK (length(nick) <= 16),
  mensaje TEXT NOT NULL CHECK (length(mensaje) <= 256)
);
