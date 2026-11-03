const inpArt = document.querySelector("#inpArt");
const inpTit = document.querySelector("#inpTit");
const inpLen = document.querySelector("#inpLen");
const btnAddSong = document.querySelector("#btnAddSong");
const feedback1 = document.querySelector("#feedback1");

const inpSearch = document.querySelector("#inpSearch");
const btnSearch = document.querySelector("#btnSearch");

const btnSortArtist = document.querySelector("#btnSortArtist");
const btnSortTitle = document.querySelector("#btnSortTitle");
const btnSortLenInc = document.querySelector("#btnSortLenInc");
const btnSortLenDec = document.querySelector("#btnSortLenDec");

const inpDelete = document.querySelector("#inpDelete");
const btnDelete = document.querySelector("#btnDelete");
const feedback2 = document.querySelector("#feedback2");

const inpEdit = document.querySelector("#inpEdit");
const btnEdit = document.querySelector("#btnEdit");
const feedback3 = document.querySelector("#feedback3");

const divSongList = document.querySelector("#divSongList");

let db = JSON.parse(localStorage.getItem("db") || "[]");
let inc = true;
ShowSong();

btnAddSong.addEventListener("click", AddSong);
btnSearch.addEventListener("click", SearchSong);
btnSortArtist.addEventListener("click", orderByArtist);
btnSortTitle.addEventListener("click", orderByTitle);
btnSortLenDec.addEventListener("click", orderByLengthDsc);
btnSortLenInc.addEventListener("click", orderByLengthAsc);
btnDelete.addEventListener("click", DeleteSong);

function DeleteSong(){
  db.splice(parseInt(inpDelete.value-1),1);
  localStorage.setItem("db",JSON.stringify(db));
 ShowSong(); 
}

function ShowSong() {
  divSongList.innerHTML = "";
  db.forEach((element, i) => {
    divSongList.innerHTML += `${i + 1}. <b>${element.artist}</b> - <i>${element.title}</i> ${secFormat(element.duration)}<br>`;
  });
}

function AddSong() {
  const title = inpTit.value.trim();
  const artist = inpArt.value.trim();
  const duration = parseInt(inpLen.value);
  if (title.length > 0 && artist.length > 0 && duration > 0) {
    db.push({ title: title, artist: artist, duration: duration });
    localStorage.setItem("db", JSON.stringify(db));
    ShowSong();
  }
}

function SearchSong(){
  divSongList.innerHTML = "" 
  const title = inpTit.value.trim();
  const artist = inpArt.value.trim();
  const duration = parseInt(inpLen.value);
if (inpSearch.value==title||inpSearch.textContent==artist||inpSearch.textContent.valueOf()==secFormat(duration)) {
  db.forEach((element, i) => {
    divSongList.innerHTML += `${i + 1}. <b>${element.artist}</b> - <i>${element.title}</i> (${element.duration})<br>`;
  });
  }
  ShowSong();
}

function orderByTitle() {
db.sort((a,b)=> a.title.localeCompare(b.title) || b.title.localeCompare(a.title));
  ShowSong();
}
function orderByArtist() {
  db.sort((a,b)=> a.artist.localeCompare(b.artist) || b.artist.localeCompare(a.artist));
  ShowSong();
}
function orderByLengthAsc() {
  asc=true;
    db.sort((a,b)=>asc ? b.duration-a.duration : a.duration-b.duration);
  ShowSong();
}
function orderByLengthDsc() {
  asc=false;
    db.sort((a,b)=>asc ? b.duration-a.duration : a.duration-b.duration);
  ShowSong();
}
function secFormat(seconds){
  let minutes=0;
  let hours=0;
  while (seconds>=60) {
    minutes++;
    seconds-=60;
  }
  hours<10 ? hours="0"+hours : hours;
  minutes<10 ? minutes="0"+minutes : minutes
  seconds<10 ? seconds="0"+seconds : seconds;

  let durationF=hours+":"+minutes+":"+seconds;
  return durationF;
}
