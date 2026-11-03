# Chuleta de JavaScript para el examen

Los ejercicios del profe (`javascript-26-27/ej01` a `ej10`) y las hojas de refuerzo 2 y 3 siguen casi todos el mismo esqueleto: coges elementos del DOM, escuchas un evento, lees y validas lo que escribe el usuario, lo guardas en un array de objetos y lo pintas en una lista o una tabla. El ej10 junta todo eso, y la hoja 3 es lo mismo con datos aleatorios. Si eres capaz de hacer un ej10 sin mirar nada, el examen lo tienes cubierto.

## Lo que tienes que saberte de memoria

1. Las referencias van arriba del todo: `const x = document.querySelector("#id")`. Como el `<script>` lleva `defer`, no hace falta esperar a `DOMContentLoaded`.
2. Eventos: `click` en botones, `keyup` con `e.key === "Enter"` en las cajas de texto, `input` para filtrar mientras se escribe y `change` en los `<select>`. La función se pasa sin paréntesis: `addEventListener("click", alta)`.
3. `.value` se usa en `input`, `select` y `textarea`, y `.textContent` en `p`, `span`, `label`, `div` y `td`. `.value` siempre devuelve texto (`"5" + 1` da `"51"`), así que pasa por `parseInt` o `Number` antes de hacer cuentas.
4. `innerHTML` solo para meter HTML tuyo, como un svg, o para vaciar (`tbody.innerHTML = ""`). Lo que escribe el usuario va siempre con `textContent`.
5. Para crear: `document.createElement("li")`, lo rellenas con `textContent` y lo cuelgas con `append`. En tablas, `tbody.insertRow()` y `fila.insertCell()`. Para borrar, `elemento.remove()`.
6. `classList.add/remove/toggle/contains`. `toggle("is-invalid", condicion)` pone o quita la clase según el booleano y te ahorra los ocho `add/remove` por campo que tiene el ej10.
7. Delegación de eventos (ej09 y ej10): un solo listener en el `tbody` y dentro `e.target.closest(".clase")`. El profe insiste mucho en esto, y además funciona con filas que se crean más tarde.
8. Los datos viven en el array. Añadir, borrar y ordenar se hace sobre el array, y después `render()` vacía la tabla y la pinta entera otra vez.
9. localStorage: al cargar, `JSON.parse(localStorage.getItem("db") || "[]")`, y `localStorage.setItem("db", JSON.stringify(db))` cada vez que el array cambie.
10. Temporizadores (ej07, ej08): `const id = setInterval(f, 1000)` y `clearInterval(id)`. Antes de arrancar uno nuevo, para el anterior, porque si no, al pulsar dos veces "Empezar" corren dos a la vez.
11. Para mover algo: `el.style.left = x + "px"`. Sin el `"px"` no se mueve.

## Arrays (hojas 2 y 3)

```js
const azar = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min
const elegir = arr => arr[Math.floor(Math.random() * arr.length)]

personas.push({ nombre: elegir(nombres), ap1: elegir(apellidos), ap2: elegir(apellidos), ciudad: elegir(ciudades), edad: azar(18, 99) })

const porEdad = [...personas].sort((a, b) => b.edad - a.edad)          // números, de mayor a menor
const porApellidos = [...personas].sort((a, b) => a.ap1.localeCompare(b.ap1) || a.ap2.localeCompare(b.ap2))
const mayores = personas.filter(p => p.edad > limite)
const media = personas.reduce((suma, p) => suma + p.edad, 0) / personas.length
const nombresSolo = personas.map(p => p.nombre)
const pos = personas.findIndex(p => p.nombre === "Ana")              // -1 si no está

arr.splice(i, 1)                      // quita 1 en la posición i
arr.splice(i, 0, "Roberto", "Amaya")  // inserta en i sin quitar nada
arr.unshift("Marta")                  // al principio
arr.indexOf("Celia")
```

Errores típicos con arrays y valores:

- `sort()` sin función ordena como texto, así que `[10, 9, 1].sort()` da `[1, 10, 9]`. Además cambia el array original; si lo quieres conservar, ordena una copia (`[...arr]`).
- `toFixed(2)` devuelve texto, no un número.
- Un `return` dentro de `forEach` hace de `continue`, y en `forEach` no existe `break`.
- `prompt()` devuelve `null` si el usuario cancela. Guarda la respuesta en una variable antes del `filter`; si lo llamas dentro, sale un prompt por cada persona.
- Un `<select>` cuya primera opción es "Elige..." se valida con `selectedIndex > 0`. Ojo, que `select.value` es texto (`"0"`).
- Puedes llamar a una función antes de su declaración, pero a una clase no, y tampoco puedes declarar la misma clase en dos archivos. El ej08 del profe declara `class Ball` en `ball.js` y otra vez en `script.js`, y node da `Identifier 'Ball' has already been declared`.
- Como el profe no pone punto y coma, no empieces nunca una línea con `[` o `(`: se pegaría a la línea de arriba. Por eso en el bloque de arriba cada `[...personas]` va detrás de un `const`.

## Plantilla para un ejercicio tipo

Es el ej10 recortado: valida los campos, añade, ordena por edad, filtra y, con la tabla filtrada, borra la fila correcta. Hay una diferencia con la del profe: el filtro se aplica dentro de `render()` en lugar de en un segundo array `filtered`. Con dos arrays, al añadir un juego se pierde el filtro, y el índice de una fila filtrada no coincide con el de `db`.

```html
<input id="nombre"> <input id="edad" type="number">
<select id="ciudad"><option>Elige ciudad</option><option>Murcia</option><option>Lorca</option></select>
<button id="btnAdd">Añadir</button> <span id="error"></span>
<input id="filtro" placeholder="Buscar">
<table id="tabla">
  <thead><tr><th>Nombre</th><th id="thEdad">Edad</th><th>Ciudad</th><th></th></tr></thead>
  <tbody></tbody>
</table>
```

```js
// 1. Referencias (con <script defer> el HTML ya está cargado)
const nombre = document.querySelector("#nombre")
const edad = document.querySelector("#edad")
const ciudad = document.querySelector("#ciudad")
const btnAdd = document.querySelector("#btnAdd")
const filtro = document.querySelector("#filtro")
const error = document.querySelector("#error")
const tbody = document.querySelector("#tabla tbody")
const thEdad = document.querySelector("#thEdad")

// 2. Datos: el array manda, la tabla solo lo pinta
let db = JSON.parse(localStorage.getItem("db") || "[]")
let asc = true

render()
nombre.focus()

// 3. Eventos
btnAdd.addEventListener("click", alta)
nombre.addEventListener("keyup", e => { if (e.key === "Enter") alta() })
filtro.addEventListener("input", render)

thEdad.addEventListener("click", () => {
    asc = !asc
    db.sort((a, b) => asc ? a.edad - b.edad : b.edad - a.edad)
    render()
})

// delegación: un listener para todos los botones de borrar, también los que aún no existen
tbody.addEventListener("click", e => {
    const btn = e.target.closest(".borrar")
    if (!btn) return
    db.splice(btn.dataset.i, 1)
    guardar()
    render()
})

// 4. Funciones
function alta() {
    const n = nombre.value.trim()
    const e = parseInt(edad.value)
    // en variables para que se marquen los tres; con && seguidos se pararía en el primer fallo
    const okNombre = marcar(nombre, n.length > 0)
    const okEdad = marcar(edad, e >= 18 && e <= 99)
    const okCiudad = marcar(ciudad, ciudad.selectedIndex > 0)
    if (!okNombre || !okEdad || !okCiudad) {
        error.textContent = "Revisa los campos marcados"
        return
    }
    db.push({ nombre: n, edad: e, ciudad: ciudad.options[ciudad.selectedIndex].textContent })
    guardar()
    render()
    limpiar()
}

function render() {
    const texto = filtro.value.trim().toLowerCase()
    tbody.innerHTML = ""
    db.forEach((p, i) => {
        if (!`${p.nombre} ${p.edad} ${p.ciudad}`.toLowerCase().includes(texto)) return // return en forEach = continue
        const fila = tbody.insertRow()
        fila.insertCell().textContent = p.nombre
        fila.insertCell().textContent = p.edad
        fila.insertCell().textContent = p.ciudad
        const btn = document.createElement("button")
        btn.className = "btn btn-danger btn-sm borrar"
        btn.textContent = "Borrar"
        btn.dataset.i = i // posición en db, vale aunque la tabla esté filtrada
        fila.insertCell().append(btn)
    })
}

function marcar(campo, valido) {
    campo.classList.toggle("is-valid", valido)
    campo.classList.toggle("is-invalid", !valido)
    return valido
}

function limpiar() {
    nombre.value = ""
    edad.value = ""
    ciudad.selectedIndex = 0
    error.textContent = ""
    document.querySelectorAll(".is-valid").forEach(el => el.classList.remove("is-valid"))
    nombre.focus()
}

function guardar() {
    localStorage.setItem("db", JSON.stringify(db))
}
```

Si te dan el HTML con Bootstrap del ej10, el `.invalid-feedback` es hermano del `div.form-floating`, no del input. Para que salga el mensaje en rojo tienes que marcar también `campo.parentElement`, como ya hiciste en skel10.

## Fallos que ya te han salido

- `skel4`: cuando aciertas no haces `return`, así que "right number" queda tapado por "too low" y además se resta un intento.
- `skel2`: con `rentRaw > 1 ? rentRaw / 100 : rentRaw`, un 1 % se calcula como un 100 %. Y si los euros no son válidos sales con `return` sin avisar, cuando el enunciado pide explicar el error.
- `skel0`: calculas `years` ya corregido, pero luego imprimes otra resta sin corregir.
- `blackjack.js`: `endGame` no tiene en cuenta que alguien se pase de 21. Si te pasas tú o se pasa el crupier, no aparece ningún mensaje.
