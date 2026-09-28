document.addEventListener("click", (e) => {
  if (e.target.id !== "calcularBtn") return;

  const inputDate = document.querySelector("input").valueAsDate;
  const now = new Date();

  if (!inputDate || inputDate > now) {
    document.querySelectorAll("label")[1].textContent = "Fecha no valida";
    return;
  }

  let months = now.getMonth() - inputDate.getMonth();
  let days = now.getDate() - inputDate.getDate();
  let years = now.getFullYear() - inputDate.getFullYear();

  if (inputDate.getDate() > now.getDate()) {
    months += 12;
    days += 30;
    years -= 1;
  }

  document.querySelectorAll("label")[1].textContent =
    `Tienes ${now.getFullYear() - inputDate.getFullYear()} years ${months} meses ${days} dias`;
});
