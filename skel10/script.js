//código JS
const game = document.querySelector("#game");
const year = document.querySelector("#year");
const platform = document.querySelector("#platform");
const sendBtn = document.querySelector("#sendBtn");
const videogamesList = document.querySelector("#videogamesList>tbody");

const db = [
  { title: "hola", year: "1970", platform: "dos" },
  { title: "adios", year: "1975", platform: "win" },
  { title: "que tal", year: "1965", platform: "atari" },
];

clearValidation();
renderGames();

game.addEventListener("input", validateGame);
year.addEventListener("input", validateYear);
platform.addEventListener("change", validatePlatform);

sendBtn.addEventListener("click", function () {
  // se validan los tres antes de comprobar, para que se marquen todos a la vez
  const results = [validateGame(), validateYear(), validatePlatform()];
  if (results.every((ok) => ok)) {
    insertGame();
    resetForm();
  }
});

videogamesList.addEventListener("click", function (e) {
  const button = e.target.closest(".btn-danger");
  if (!button) return;
  db.splice(button.dataset.index, 1);
  renderGames();
});

function insertGame() {
  db.push({
    title: game.value,
    year: year.value,
    platform: platform[platform.value].textContent,
  });
  renderGames();
}

function renderGames() {
  videogamesList.innerHTML = "";
  db.forEach((e, i) => {
    const newTr = videogamesList.insertRow();
    const newTD1 = newTr.insertCell();
    const newTD2 = newTr.insertCell();
    const newTD3 = newTr.insertCell();
    const newTD4 = newTr.insertCell();
    newTD1.textContent = e.title;
    newTD2.textContent = e.year;
    newTD3.textContent = e.platform;
    const deleteButton = document.createElement("button");
    deleteButton.textContent = "Delete";
    deleteButton.className = "btn btn-danger btn-sm";
    deleteButton.dataset.index = i;
    newTD4.append(deleteButton);
  });
}

function validateGame() {
  return setValid(game, game.value.trim().length > 0);
}

function validateYear() {
  return setValid(year, /^\d{4}$/.test(year.value.trim()));
}

function validatePlatform() {
  // la opción "Elige plataforma" no tiene value, así que se mira el índice
  return setValid(platform, platform.selectedIndex > 0);
}

function setValid(field, valid) {
  // el borde lo pinta la clase del campo; el mensaje .invalid-feedback, la del .form-floating que lo envuelve
  [field, field.parentElement].forEach((el) => {
    el.classList.toggle("is-valid", valid);
    el.classList.toggle("is-invalid", !valid);
  });
  return valid;
}

function clearValidation() {
  document
    .querySelectorAll(".is-valid, .is-invalid")
    .forEach((el) => el.classList.remove("is-valid", "is-invalid"));
}

function resetForm() {
  game.value = "";
  year.value = "";
  platform.selectedIndex = 0;
  clearValidation();
  game.focus();
}
