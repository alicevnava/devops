<?php
declare(strict_types=1);

$nome = 'Treinamento Linux';
$ambiente = getenv('APP_ENV') ?: 'VM de treinamento';
$servidor = $_SERVER['SERVER_SOFTWARE'] ?? 'Web server';
$dataHora = date('d/m/Y H:i:s');
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= htmlspecialchars($nome, ENT_QUOTES, 'UTF-8') ?></title>
    <style>
        :root {
            color-scheme: dark;
            font-family: Arial, sans-serif;
        }

        body {
            align-items: center;
            background: #101827;
            color: #e5e7eb;
            display: flex;
            justify-content: center;
            margin: 0;
            min-height: 100vh;
        }

        main {
            background: #1f2937;
            border: 1px solid #374151;
            border-radius: 16px;
            box-shadow: 0 20px 50px rgb(0 0 0 / 25%);
            max-width: 640px;
            padding: 40px;
            width: calc(100% - 48px);
        }

        h1 {
            color: #93c5fd;
            margin-top: 0;
        }

        .status {
            color: #86efac;
            font-weight: bold;
        }

        dl {
            display: grid;
            gap: 12px;
            grid-template-columns: 140px 1fr;
            margin-bottom: 0;
        }

        dt {
            color: #9ca3af;
        }

        dd {
            margin: 0;
            overflow-wrap: anywhere;
        }
    </style>
</head>
<body>
    <main>
        <h1>Página publicada com sucesso!</h1>
        <p class="status">A aplicação PHP está respondendo pelo web server.</p>
        <dl>
            <dt>Ambiente</dt>
            <dd><?= htmlspecialchars($ambiente, ENT_QUOTES, 'UTF-8') ?></dd>

            <dt>Servidor</dt>
            <dd><?= htmlspecialchars($servidor, ENT_QUOTES, 'UTF-8') ?></dd>

            <dt>Data e hora</dt>
            <dd><?= htmlspecialchars($dataHora, ENT_QUOTES, 'UTF-8') ?></dd>
        </dl>
    </main>
</body>
</html>
