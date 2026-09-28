const guess = document.getElementById("guess");
const submitBtn = document.querySelector("#submitBtn");
const message = document.querySelector("#message");
const secret = Math.floor(Math.random() * 100) + 1;
const attempts = document.querySelector("#attempts");
// console.log("secret=" + secret);
let tries = 6;

guess.addEventListener("keydown", (e) => {
  if (e.key == "Enter") {
    checkNumber();
  }
});
submitBtn.addEventListener("click", checkNumber);
function checkNumber(params) {
  let userTry = parseInt(guess.value);
  if (userTry === secret) {
    message.textContent = "right number";
    submitBtn.disabled = true;
  }
  message.textContent = userTry > secret ? "too high" : "too low";
  tries--;
  attempts.textContent = "Remaining attempts: " + tries;
  if (tries <= 0) {
    message.textContent = "Game over! Was " + secret;
    guess.disabled = submitBtn.disabled = true;
  }
}
