const txt = document.querySelector("#txtAdd");
const mylist = document.querySelector("#mylist");
const mycart = document.querySelector("#mycart");
const btnAdd = document.querySelector("#btnAdd");

function addItem() {
  const val = txt.value.trim();
  if (!val) return;

  const li = document.createElement("li");
  li.textContent = val;
  mylist.append(li);

  txt.value = "";
  txt.focus();
}

txt.addEventListener("keydown", (e) => {
  if (e.key === "Enter") addItem();
});

btnAdd.addEventListener("click", addItem);
mylist.addEventListener("click", (e) => {
  e.target.closest("li")?.classList.toggle("seleccionado");
});

document.querySelector("#btnSelAll").addEventListener("click", () => {
  mylist
    .querySelectorAll("li")
    .forEach((li) => li.classList.add("seleccionado"));
});

document.querySelector("#btnSelNot").addEventListener("click", () => {
  mylist
    .querySelectorAll("li")
    .forEach((li) => li.classList.remove("seleccionado"));
});

document.querySelector("#btnInvSel").addEventListener("click", () => {
  mylist
    .querySelectorAll("li")
    .forEach((li) => li.classList.toggle("seleccionado"));
});

document.querySelector("#btnDelSel").addEventListener("click", () => {
  mylist.querySelectorAll(".seleccionado").forEach((li) => li.remove());
});

document.querySelector("#btnMovSel").addEventListener("click", () => {
  mylist.querySelectorAll(".seleccionado").forEach((li) => {
    li.classList.remove("seleccionado");
    mycart.append(li);
  });
});
