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


		if (isset($_SERVER['HTTP_X_REQUESTED_WITH']) && (string)$_SERVER['HTTP_X_REQUESTED_WITH'] === 'pale_white/ajax') {
			$is_ajax = true;
			error_log("[PaleWhite] routing ajax '$path'");
		} else {
			$is_ajax = false;
			error_log("[PaleWhite] routing '$path'");
		}


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
					throw new \PaleWhite\PaleWhiteException("failed to generate csrf token, not enough entropy");
				$_SESSION['pale_white_csrf_token'] = bin2hex($seed);
			}

			if (isset($_SERVER['CONTENT_TYPE']) && $_SERVER['CONTENT_TYPE'] === 'application/json') {
				// get json input from ajax request
				$input = file_get_contents('php://input');
				$args = json_decode($input, true);
				// error_log("[PaleWhite] got json request data: " . json_encode($args));

			} else {
				// process any post arguments
				$args = array();
				foreach ($_POST as $k => $v)
					$args[$k] = $v;

				// process any file uploads into args
				foreach ($_FILES as $field => $file_upload)
				{
					// error_log("[PaleWhite] \$_FILES[$field]: " . json_encode($file_upload));
					if (!isset($file_upload['error']) || is_array($file_upload['error']))
						throw new \PaleWhite\PaleWhiteException("invalid file upload");
					if ($file_upload['error'] === UPLOAD_ERR_INI_SIZE)
						throw new \PaleWhite\PaleWhiteException("file upload failed: size exceeded");
						// may need to increase upload limits in your php.ini
						// under post_max_size and upload_max_filesize
					if ($file_upload['error'] === UPLOAD_ERR_PARTIAL)
						throw new \PaleWhite\PaleWhiteException("file upload failed: failed to upload whole file");
					if ($file_upload['error'] === UPLOAD_ERR_NO_TMP_DIR)
						throw new \PaleWhite\PaleWhiteException("file upload failed: no tmp directory");
					if ($file_upload['error'] === UPLOAD_ERR_CANT_WRITE)
						throw new \PaleWhite\PaleWhiteException("file upload failed: cant write directory");
					if ($file_upload['error'] === UPLOAD_ERR_OK) {
						$file_container = new \PaleWhite\FileUpload($file_upload['tmp_name'], $file_upload['size']);
						$args[$field] = $file_container;
					} elseif ($file_upload['error'] === UPLOAD_ERR_NO_FILE) {
						$args[$field] = null;
					} else {
						throw new \PaleWhite\PaleWhiteException("file upload failed");
					}
				}
				// error_log("[PaleWhite] got post request data: " . json_encode($args));
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

			if ($is_ajax) {
				$controller->route_ajax($request, $response);
			} else {
				$controller->route($request, $response);
			}

		} catch (\Exception $e) {
			// last-chance exception catch
			$response = new \PaleWhite\Response();
			$response->status = "500 Server Error";
			if ($is_ajax) {
				if ($config['show_exception_trace']) {
					// show a detailed dump of data if show_exception_trace is enabled
					$exception_trace = array(
						'exception_class' => get_class($e),
						'exception_message' => $e->getMessage(),
						'file' => $e->getFile(),
						'line' => $e->getLine(),
						'stacktrace' => array(),
					);

					foreach ($e->getTrace() as $trace) {
						$message = $trace['file'] . "(" . $trace['line'] . "): ";
						if (isset($trace['class'])) {
							$message .= $trace['class'] . $trace['type'];
						}
						$message .= $trace['function'];

						$exception_trace['stacktrace'][] = $message;
					}

					$response->body .= "</body></html>";
					$response->body = array(
						'status' => 'error',
						'error' => 'a "' . get_class($e) . '" exception occurred: ' . $e->getMessage(),
						'exception_trace' => $exception_trace,
					);
				} else {
					// show a bland server error message
					$response->body = array('status' => 'error', 'error' => 'Server Exception Occurred');
				}
			} else {
				if ($config['show_exception_trace']) {
					// show a detailed dump of data if show_exception_trace is enabled
					$response->body = "<!doctype html><html><head><title>Server Error</title></head><body>";

					$response->body .= "<h1>a '" . get_class($e) . "' exception occurred:</h1>";
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
					$response->body = "<!doctype html><html><head><title>Server Error</title></head>"
						. "<body>Server Exception Occurred</body></html>";
				}
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

		// if the response has a redirect, send it
		foreach ($response->headers as $header => $value) {
			header("$header: $value");
		}

		// send the body
		if ($response->body !== null) {
			if ($response->body instanceof \PaleWhite\FileDirectoryFile) {
				error_log("[PaleWhite] sending file: '" . $response->body->filepath . "'");
				readfile($response->body->filepath);
			} elseif (is_array($response->body)) {
				if (!isset($response->headers['content-type']))
					header("Content-Type: application/json");
				echo(json_encode($response->body));
			} else {
				echo($response->body);
			}
		}
	}
}


