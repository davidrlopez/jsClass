<?php

if (isset($_GET['ultimo'])) {
    $con = new PDO("sqlite:" . __DIR__ . "/chat.db");
    $consulta = "SELECT json_group_array(json_object('id', id, 'nick', nick, 'texto', mensaje, 'fecha', instante) ORDER BY id)
                 FROM mensajes WHERE id > ?";
    $sen = $con->prepare($consulta);
    $sen->execute([$_GET['ultimo']]);
    header('Content-Type: application/json');
    echo $sen->fetchColumn();
} else {
    echo "No has pasado los parámetros correctos. Debes pasar 'ultimo'";
}
