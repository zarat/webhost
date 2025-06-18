<?php

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    header("Content-Type: text/plain");

    if (!isset($_POST["username"], $_POST["email"]) || empty($_POST["username"]) || empty($_POST["email"])) {
        http_response_code(400);
        exit("Benutzername und E-Mail sind erforderlich.");
    }

    $username = escapeshellarg($_POST["username"]);
    $email = escapeshellarg($_POST["email"]);

    $cmd = "sudo /root/webhost/create-vhost.sh $username $email 2>&1";
    $output = shell_exec($cmd);

    echo $output ?: "Keine Ausgabe vom Script.";
    exit;
}
else {
    include "header.php";
}
?>

<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Webspace Registrierung</title>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-50">
  <!-- <header class="bg-white shadow">
    <div class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
      <h1 class="text-3xl font-bold text-gray-900">Kostenloser Webspace</h1>
    </div>
  </header> -->

  <main class="mt-10">
    <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
      <h2 class="text-4xl font-extrabold text-gray-900">Webspace</h2>

        <p class="mt-4 text-lg text-gray-600">
        Dein eigener Webspace mit 1 GB Speicher, PHP, unbegrenzt MySQL Datenbanken und unbegrenzt Traffic (Fair Use Prinzip).
        Du bekommst Zugriff via FTP um deine Dateien hochzuladen.
        Deine Website liegt hinter einem Reverse-Proxy und wird mit einem kostenlosen SSL Zertifikat versehen.
        </p>

      <p class="mt-4 text-lg text-gray-600">
        <p><b><span style="color:red">ACHTUNG</span></b>: Dein Webspace kann <b>in der Beta Phase</b> jederzeit gelöscht werden!</p>
      </p>
      <p class="mt-4 text-lg text-gray-600">
        Features
        <ul>
                <li>Subdomain: deinname.zarat.at</li>
                <li>1 GB Speicher</li>
                <li>PHP 8</li>
                <li>unbegrenzt MySQL Datenbanken</li>
                <li>unbegrenzt Traffic (Fair Use)</li>
                <li>FTP Zugriff</li>
                <li>LetsEncrypt Zertifikat</li>
        </ul>
      </p>
    </div>

    <div class="mt-10 max-w-2xl mx-auto px-4 sm:px-6 lg:px-8">
      <form id="registerForm" class="bg-white shadow-md rounded px-8 pt-6 pb-8 mb-4">
        <div class="mb-4">
          <label class="block text-gray-700 text-sm font-bold mb-2" for="username">Benutzername</label>
          <input name="username" required class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700" id="username" type="text" placeholder="deinname">
        </div>
        <div class="mb-4">
          <label class="block text-gray-700 text-sm font-bold mb-2" for="email">E-Mail</label>
          <input name="email" required class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700" id="email" type="email" placeholder="you@example.com">
        </div>
        <div class="flex items-center justify-between">
          <button class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded" type="submit">
            Kostenlos registrieren
          </button>
        </div>
      </form>

<div id="loading" class="mt-4 p-4 bg-yellow-100 rounded text-sm text-yellow-800 hidden">
  <span id="loading-text">Webserver wird vorbereitet …</span>
</div>

      <div id="response" class="mt-4 p-4 bg-gray-100 rounded text-sm whitespace-pre hidden"></div>

      <!-- <p class="text-center text-gray-500 text-xs mt-4">
        Durch die Registrierung stimmst du unseren <a href="#" class="underline">Nutzungsbedingungen</a> zu.
      </p> -->
    </div>
  </main>

  <footer class="mt-16 bg-white border-t">
    <div class="max-w-7xl mx-auto py-4 px-4 text-center text-gray-500 text-sm">
      &copy; 2025 zarat.at - Alle Rechte vorbehalten.
    </div>
  </footer>

<script>
  document.getElementById("registerForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const form = e.target;
    const formData = new FormData(form);

    const formBox = document.getElementById("registerForm");
    const loadingBox = document.getElementById("loading");
    const loadingText = document.getElementById("loading-text");
    const responseBox = document.getElementById("response");

    const messages = [
      "Webspace wird vorbereitet …",
      "Container wird gestartet …",
      "Zugangsdaten werden erstellt …",
      "Fast fertig …"
    ];
    let msgIndex = 0;
    let finished = false;

    // Formular ausblenden, Ladeanzeige einblenden
    formBox.classList.add("hidden");
    loadingBox.classList.remove("hidden");
    responseBox.classList.add("hidden");
    responseBox.textContent = "";

    // Statusmeldungen einmal durchlaufen
    const updateMessage = () => {
      if (finished) return;
      if (msgIndex < messages.length) {
        loadingText.textContent = messages[msgIndex];
        msgIndex++;
        setTimeout(updateMessage, 4000);
      }
    };
    updateMessage();

    try {
      const res = await fetch("", {
        method: "POST",
        body: formData,
      });

      const text = await res.text();

      finished = true;
      loadingText.textContent = text;

    } catch (error) {
      finished = true;
      loadingText.textContent = "Ein Fehler ist aufgetreten. Bitte versuche es später erneut.";
    }
  });
</script>

</body>
</html>
