-- La misma tabla que la de SQLite, con los tipos de Postgres
CREATE TABLE IF NOT EXISTS mensajes (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  -- texto en hora local, igual que la versión de SQLite, para que el JSON salga idéntico
  instante TEXT NOT NULL DEFAULT to_char(now(), 'YYYY-MM-DD HH24:MI:SS'),
  nick TEXT NOT NULL CHECK (char_length(nick) <= 16),
  mensaje TEXT NOT NULL CHECK (char_length(mensaje) <= 256)
);
