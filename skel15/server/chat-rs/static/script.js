//document.write("hola, mundo, pijo!")
// Cliente del chat: pide los mensajes nuevos cada pocos segundos y envía los del usuario.
// Los PHP del servidor están en la carpeta "server/", junto a este archivo.
const URL_ENVIAR = "/api/mensajes";
const URL_LEER = "/api/mensajes";
const INTERVALO_MS = 2000;

const chat = document.getElementById("chat");
const nick = document.getElementById("nick");
const teclado = document.getElementById("teclado");
const enviar = document.getElementById("enviar");

// Mismos límites que los CHECK de la tabla (nick <= 16, mensaje <= 256)
nick.maxLength = 16;
teclado.maxLength = 256;

let ultimo = 0; // id del último mensaje recibido; el servidor devuelve los que tengan id > ultimo
let leyendo = false; // evita dos peticiones de lectura a la vez (si no, se duplicarían mensajes)

function pintarMensaje(m) {
  const caja = document.createElement("div");
  caja.className = "mensaje";

  const cabecera = document.createElement("span");
  cabecera.className = "fechahora";
  cabecera.textContent = m.fecha + " · " + m.nick;

  const texto = document.createElement("div");
  texto.textContent = m.texto; // textContent y no innerHTML: un mensaje con <script> no se ejecuta

  caja.append(cabecera, texto);
  chat.appendChild(caja);
}

async function traerNuevos() {
  if (leyendo) return;
  leyendo = true;
  try {
    const resp = await fetch(URL_LEER + "?ultimo=" + ultimo);
    if (!resp.ok) throw new Error("HTTP " + resp.status);
    const mensajes = await resp.json();

    if (mensajes.length > 0) {
      // Si el usuario ya está abajo del todo, seguimos bajando; si está leyendo arriba, no le movemos
      const alFinal =
        chat.scrollHeight - chat.scrollTop - chat.clientHeight < 40;
      for (const m of mensajes) {
        pintarMensaje(m);
        ultimo = Math.max(ultimo, Number(m.id));
      }
      if (alFinal) chat.scrollTop = chat.scrollHeight;
    }
  } catch (e) {
    console.error("No se pudieron leer los mensajes:", e);
  } finally {
    leyendo = false;
  }
}

// Bucle de lectura: espera a que termine cada petición antes de programar la siguiente
async function bucle() {
  await traerNuevos();
  setTimeout(bucle, INTERVALO_MS);
}

async function enviarMensaje() {
  const n = nick.value.trim();
  const t = teclado.value.trim();
  if (n === "" || t === "") {
    alert("Escribe un nick y un mensaje");
    return;
  }

  enviar.disabled = true;
  try {
    const resp = await fetch(URL_ENVIAR, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ nick: n, mensaje: t }),
    });
    if (!resp.ok) throw new Error("HTTP " + resp.status);
    teclado.value = "";
    await traerNuevos(); // el mensaje propio aparece sin esperar al siguiente ciclo
  } catch (e) {
    console.error("No se pudo enviar el mensaje:", e);
    alert("No se pudo enviar el mensaje");
  } finally {
    enviar.disabled = false;
    teclado.focus();
  }
}

enviar.addEventListener("click", enviarMensaje);
teclado.addEventListener("keydown", (ev) => {
  if (ev.key === "Enter") enviarMensaje();
});

bucle();
