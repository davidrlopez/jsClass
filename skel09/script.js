//código JS
const COMPANIES = [
  "Microsoft",
  "Apple",
  "Google",
  "Cisco",
  "Amazon",
  "Nvidia",
  "Intel",
  "Patatas Acho",
];

const studentName = document.querySelector("#studentName");
const choice1 = document.querySelector("#choice1");
const choice2 = document.querySelector("#choice2");
const insertButton = document.querySelector("#insertButton");
const errorMsg = document.querySelector("#errorMsg");
const choicesBody = document.querySelector("#studentsChoices>tbody");

studentName.focus();
choice2.disabled = true;
insertButton.disabled = true;

popularChoice(choice1);
popularChoice(choice2);
choice1.addEventListener("change", function () {
  const chosen = choice1.value;
  choice2.innerHTML = "<OPTION value='0'>(choose one)</OPTION>";
  if (chosen != 0) {
    popularChoice(choice2);
    choice2.remove(chosen);
    choice2.disabled = false;
  } else {
    choice2.disabled = true;
  }
  checkInsertButtonRequisites();
});
choice2.addEventListener("change", checkInsertButtonRequisites);
studentName.addEventListener("input", checkInsertButtonRequisites);

insertButton.addEventListener("click", function () {
  if (checkInsertButtonRequisites()) createNewUserPreferenceRow();
});

choicesBody.addEventListener("click", function (e) {
  const button = e.target.closest(".btn-danger");
  if (button) button.closest("tr").remove();
});

function createNewUserPreferenceRow() {
  const userName = studentName.value.trim();
  const company1 = COMPANIES[choice1.value - 1];
  const company2 = COMPANIES[choice2.value - 1];

  const newTr = choicesBody.insertRow();
  const newTD1 = newTr.insertCell();
  const newTD2 = newTr.insertCell();
  const newTD3 = newTr.insertCell();
  const newTD4 = newTr.insertCell();
  newTD1.textContent = userName;
  newTD2.textContent = company1;
  newTD3.textContent = company2;
  const deleteButton = document.createElement("button");
  deleteButton.textContent = "Delete";
  deleteButton.className = "btn btn-danger btn-sm";
  newTD4.append(deleteButton);
}
function popularChoice(choice) {
  COMPANIES.forEach((e, i) => {
    const newOption = document.createElement("OPTION");
    choice.append(newOption);
    newOption.textContent = e;
    newOption.value = i + 1;
  });
}

function checkInsertButtonRequisites() {
  const valid =
    studentName.value.trim().length > 0 &&
    choice1.value != 0 &&
    choice2.value != 0;
  insertButton.disabled = !valid;
  errorMsg.textContent = valid ? "" : "Insert all the requirements";
  return valid;
}
