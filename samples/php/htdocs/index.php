<?php
$uri = $_SERVER['REQUEST_URI'];

if ($uri === '/health') {
    header('Content-Type: application/json');
    echo json_encode(['status' => 'OK']);
    exit;
}

echo 'Hello from distroless buildpack builder!';
