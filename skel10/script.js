const game = document.querySelector("#game");
const year = document.querySelector("#year");
const platform = document.querySelector("#platform");
const sendBtn = document.querySelector("#sendBtn");
const videogamesList = document.querySelector("#videogamesList>tbody");
const pattern = document.querySelector("#pattern");

let db = JSON.parse(localStorage.getItem("vgList") || "[]");
let order = false;

db.sort((v1, v2) => {
  return v1.title.toLowerCase().localeCompare(v2.title.toLowerCase());
});

pattern.addEventListener("input", renderGames);
clearValidation();
renderGames();

game.addEventListener("input", validateGame);
year.addEventListener("input", validateYear);
platform.addEventListener("change", validatePlatform);

sendBtn.addEventListener("click", function () {
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
  localStorage.setItem("vgList", JSON.stringify(db));
  renderGames();
});

function insertGame() {
  db.push({
    title: game.value.trim(),
    year: year.value.trim(),
    platform: platform[platform.value].textContent.trim(),
  });
  localStorage.setItem("vgList", JSON.stringify(db));
  renderGames();
}

function renderGames() {
  const text = pattern.value.trim().toLowerCase();
  videogamesList.innerHTML = "";
  db.forEach((e, i) => {
    const matches =
      e.title.toLowerCase().includes(text) ||
      e.year.toLowerCase().includes(text) ||
      e.platform.toLowerCase().includes(text);
    if (!matches) return;
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
  return setValid(platform, platform.selectedIndex > 0);
}

function setValid(field, valid) {
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
