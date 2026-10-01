const cartaBtn = document.querySelector("#cartaBtn");
const plantarseBtn = document.querySelector("#plantarseBtn");
const resultadoTA=document.querySelector("#resultadoTA");

function rollCard(){
return Math.floor(Math.random() * 10) + 1;
}

function sumCards(stack) {
  return stack.reduce((total, card) => total + card, 0);
}
class player{
  constructor(name){
  this.name=name;
    this.cards=[];
  }
  getScore() {
  const total = sumCards(this.cards);
  return this.cards.includes(1) && total + 10 <= 21 ? total + 10 : total;
  }
}
function rollGame(player){
     let card=rollCard();
    player.cards.push(card);
  if (player.getScore()===21) {
    cartaBtn.disabled=true;
    plantarseBtn.disabled=true;
    endGame();
  }
   if (player.getScore()>21) {
      cartaBtn.disabled=true;
        plantarseBtn.disabled=true;
   endGame(); 
    }
  resultadoTA.value +=`\n ${player.name} card:${card} scoreboard:${player.getScore()}`;
  }

function endGame(){
if(client.getScore()==cupier.getScore()) resultadoTA.value +=`\n Draw!`;
if(client.getScore()>cupier.getScore() && client.getScore()<=21)resultadoTA.value+=`\n Client Winner!`;
if(cupier.getScore()>client.getScore() && cupier.getScore()<=21)resultadoTA.value+=`\n Cupier Winner!`;
}
const client = new player("Client");
const cupier = new player("Cupier");

cartaBtn.addEventListener("click", function()  {
    rollGame(client);
  });
plantarseBtn.addEventListener("click", function()  {
  cartaBtn.disabled=true;
  while(cupier.getScore()<17){
    rollGame(cupier);
      }
endGame()});
