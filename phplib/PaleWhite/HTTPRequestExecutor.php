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

		$request = new \PaleWhite\Request($path, $args);

		$response = new \PaleWhite\Response();

		try {
			$controller_class = $config['main_controller'];
			$controller = new $controller_class();
			$controller->route($request, $response);
		} catch (\Exception $e) {
			$response = new \PaleWhite\Response();
			$response->status = "500 Server Error";
			if ($config['show_exception_trace']) {
				$response->body = "<!doctype html><html><head><title>Server Error</title></head><body>";

				$response->body .= "<h1>" . $e->getMessage() . "</h1>";
				$response->body .= "<p>" . $e->getFile() . ":" . $e->getLine() . "</p>";
				foreach ($e->getTrace() as $trace) {
					$response->body .= "<p>" . $trace['file'] . ":" . $trace['line'] . "</p>";
				}

				$response->body .= "</body></html>";
			} else {
				$response->body = "<!doctype html><html><head><title>Server Error</title></head><body>Server Error</body></html>";
			}
		}

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


