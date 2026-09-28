document.getElementById("btnCalcular").onclick = () => {
  const euros = +document.getElementById("inpEurosIniciales").value;
  const rentRaw = +document.getElementById("inpRentabAnual").value;
  const anos = +document.getElementById("inpDuracion").value;

  if (euros < 100) return;

  const rent = rentRaw > 1 ? rentRaw / 100 : rentRaw;
  let saldo = euros;
  let salida = "";

  for (let i = 1; i <= anos; i++) {
    saldo *= 1 + rent;
    salida += `Año ${i}: ${saldo.toFixed(2)} €\n`;
  }

  salida += `\nRentabilidad total: ${(saldo - euros).toFixed(2)} €`;
  document.getElementById("taResultados").value = salida;
};
