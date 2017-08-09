<?php

namespace PaleWhite;

// php 5.5 doesn't support hash_equals
// taken from https://secure.php.net/hash_equals
if(!function_exists('hash_equals')) {
	function hash_equals($str1, $str2) {
		if(strlen($str1) != strlen($str2)) {
			return FALSE;
		} else {
			$res = $str1 ^ $str2;
			$ret = 0;
			for($i = strlen($res) - 1; $i >= 0; $i--) {
				$ret |= ord($res[$i]);
			}
			return !$ret;
		}
	}
}

class HTTPRequestExecutor {
	public function execute () {
		global $config;

		// process the path
		$url = parse_url(urldecode($_SERVER['REQUEST_URI']));
		$path = $url['path'];
		$path = substr($path, strlen($config['site_base']));

		error_log("[PaleWhite] routing '$path'");

		try {

			// set up the global environment
			global $database;
			$database = new \PaleWhite\DatabaseDriver($config['database_config']);

			// enable the session
			session_start();
			// error_log("[PaleWhite] _SESSION: " . json_encode($_SESSION));
			if (!isset($_SESSION['pale_white_csrf_token']))
			{
				$seed = openssl_random_pseudo_bytes(32);
				if ($seed === false)
					throw new \Exception("failed to generate csrf token, not enough entropy");
				$_SESSION['pale_white_csrf_token'] = bin2hex($seed);
			}

			// process any post arguments
			$args = array();
			foreach ($_POST as $k => $v)
				$args[$k] = $v;

			// process any file uploads into args
			foreach ($_FILES as $field => $file_upload)
			{
				// error_log("[PaleWhite] \$_FILES[$field]: " . json_encode($file_upload));
				if (!isset($file_upload['error']) || is_array($file_upload['error']))
					throw new \Exception("invalid file upload");
				if ($file_upload['error'] !== UPLOAD_ERR_OK)
					throw new \Exception("file upload failed");
				$file_container = new \PaleWhite\FileUpload($file_upload['tmp_name'], $file_upload['size']);
				$args[$field] = $file_container;
			}

			// set up api objects
			$request = new \PaleWhite\Request($path, $args);
			$response = new \PaleWhite\Response();

			// call the main controller and try to route through it
			$controller_class = $config['main_controller'];
			$controller = new $controller_class();

			// // validate a csrf token if it exists
			// if (isset($_POST['_csrf_token']))
			// 	$controller->validate_csrf_token((string)$_POST['_csrf_token']);

			$controller->route($request, $response);

		} catch (\Exception $e) {
			// last-chance exception catch
			$response = new \PaleWhite\Response();
			$response->status = "500 Server Error";
			if ($config['show_exception_trace']) {
				// show a detailed dump of data if show_exception_trace is enabled
				$response->body = "<!doctype html><html><head><title>Server Error</title></head><body>";

				$response->body .= "<h1>a '" . get_class($e) . "' exception occured:</h1>";
				$response->body .= "<h2>" . $e->getMessage() . "</h2>";
				$response->body .= "<p>at " . $e->getFile() . ":" . $e->getLine() . "</p>";

				foreach ($e->getTrace() as $trace) {
					$message = $trace['file'] . "(" . $trace['line'] . "): ";
					if (isset($trace['class'])) {
						$message .= $trace['class'] . $trace['type'];
					}
					$message .= $trace['function'];
					$response->body .= "<p>$message</p>";
				}

				$response->body .= "</body></html>";
			} else {
				// show a bland server error message
				$response->body = "<!doctype html><html><head><title>Server Error</title></head><body>Server Error</body></html>";
			}
		}

		// after the request has been process and a response has been generated

		// if the response has a status, send it
		if ($response->status !== null) {
			if (preg_match("/\A(\d+)\s+/", $response->status, $matches)) {
				$status_code = (int)$matches[1];
				header($response->status, FALSE, $status_code);
			} else {
				header($response->status, FALSE, 200);
			}
		}

		// if the response has a redirect, send it
		if ($response->redirect !== null) {
			if (substr($response->redirect, 0, 1) === '/') {
				header("Location: " . $config['site_base'] . $response->redirect);
			} else {
				header("Location: " . $response->redirect);
			}
		}

		// send the body
		if ($response->body !== null) {
			if ($response->body instanceof \PaleWhite\FileDirectoryFile) {
				error_log("[PaleWhite] sending file: '" . $response->body->filepath . "'");
				readfile($response->body->filepath);
			} else {
				echo($response->body);
			}
		}
	}
}


