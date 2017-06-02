<?php

namespace PaleWhite;

class HTTPRequestExecutor {
	public function execute () {
		global $config;
		
		global $database;
		$database = new \PaleWhite\DatabaseDriver($config['database_config']);

		session_start();
		// error_log("[PaleWhite] _SESSION: " . json_encode($_SESSION));

		$url = parse_url(urldecode($_SERVER['REQUEST_URI']));
		$path = $url['path'];
		$path = substr($path, strlen($config['site_base']));
		error_log("[PaleWhite] routing '$path'");

		$args = array();
		foreach ($_POST as $k => $v)
			$args[$k] = $v;

		$response = new \PaleWhite\Response();

		$controller_class = $config['main_controller'];
		$controller = new $controller_class();
		$controller->route($response, $path, $args);

		if ($response->status !== null) {
			if (preg_match("/\A(\d+)\s+/", $response->status, $matches)) {
				$status_code = (int)$matches[1];
				header($response->status, FALSE, $status_code);
			} else {
				header($response->status, FALSE, 200);
			}
		}

		if ($response->redirect !== null) {
			if (substr($response->redirect, 0, 1) === '/') {
				header("Location: " . $config['site_base'] . $response->redirect);
			} else {
				header("Location: " . $response->redirect);
			}
		}

		if ($response->body !== null) {
			echo($response->body);
		}
	}
}


