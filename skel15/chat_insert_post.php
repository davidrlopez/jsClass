<?php
if(isset($_POST['nick'])&&isset($_POST['mensaje'])) {
		$con = new PDO("sqlite:" . __DIR__ . "/chat.db");

		$consulta = "INSERT INTO mensajes(nick,mensaje) VALUES(?,?)";
		$sen = $con->prepare($consulta);
        $sen->bindParam(1,$_POST['nick']);
        $sen->bindParam(2,$_POST['mensaje']);
		$sen->execute();	
} else {
	echo "No has pasado los parámetros correctos. Debes pasar 'nick' y 'mensaje'";
}
?>