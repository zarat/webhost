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
?>

<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Free Webspace Registrierung</title>
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
      <h2 class="text-4xl font-extrabold text-gray-900">Starte deine eigene Website – kostenlos!</h2>
      <p class="mt-4 text-lg text-gray-600">
        Registriere deinen kostenlosen Webspace mit FTP-Zugriff, PHP, unbegrenzt MySQL Datenbanken und eigenem LetsEncrypt Zertifikat.
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
      const box = document.getElementById("registerForm");

      const res = await fetch("", {
        method: "POST",
        body: formData,
      });

      const text = await res.text();

      box.textContent += text;
      box.classList.remove("hidden");
    });
  </script>
</body>
</html>
