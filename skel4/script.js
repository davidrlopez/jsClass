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
  } else {
    message.textContent = "wrong number";
    userTry > secret
      ? (message.textContent = "too high")
      : (message.textContent = "too low");
    tries > 0 ? tries-- : (submitBtn.disabled = true);
    attempts.textContent = "Remaining attempts:" + tries;
  }
}
