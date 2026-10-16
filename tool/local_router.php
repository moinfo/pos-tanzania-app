<?php
/**
 * Router for running the Kariakoo web API on this PC with PHP's built-in server.
 *
 *   C:\xampp\php74\php.exe -c C:\xampp\php74\php.ini -S 0.0.0.0:8085 ^
 *       -t C:\xampp\htdocs\PointOfSalesTanzania\public ^
 *       C:\xampp\htdocs\pos-tanzania-app\tool\local_router.php
 *
 * (PHP 7.4, because the backend's `Attribute` model clashes with a class PHP 8
 * ships.) Then, for a USB phone:  adb reverse tcp:8085 tcp:8085  and build the
 * app with  --dart-define=LIVE_API=false.
 *
 * CI_ENV=testing selects the local no-password MySQL root and quiet errors
 * (see application/config/database.php in the web project).
 */
$_SERVER['CI_ENV'] = 'testing';

$project = 'C:/xampp/htdocs/PointOfSalesTanzania';
$root = $project . '/public';
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

// Static files under public/ are served as they are.
if ($path !== '/' && is_file($root . $path)) {
    return false;
}

// Product photos live in <project>/uploads, outside public/.
if (strpos($path, '/uploads/') === 0 && is_file($project . $path)) {
    header('Content-Type: ' . mime_content_type($project . $path));
    readfile($project . $path);
    return true;
}

chdir($root);
$_SERVER['SCRIPT_NAME'] = '/index.php';
$_SERVER['SCRIPT_FILENAME'] = $root . '/index.php';
require $root . '/index.php';
