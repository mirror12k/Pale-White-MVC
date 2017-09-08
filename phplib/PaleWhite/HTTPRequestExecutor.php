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

		// setup runtime
		global $runtime;
		$runtime = new PHPRuntime();
		// $runtime = array(
		// 	'current_localization' => (string)$config['default_localization'],
		// );

		// process the path
		// $url = parse_url(urldecode($_SERVER['REQUEST_URI']));
		// $path = $url['path'];
		// $path = substr($path, strlen($config['site_base']));





		try {


			// set up the global environment
			$runtime->initialize_http();
			$runtime->initialize_session();
			$runtime->initialize_database();

			if ($config['maintenance_mode']) {
				// call the maintenance controller
				$controller_class = $config['maintenance_mode_controller'];
			} else {
				// call the main controller and try to route through it
				$controller_class = $config['main_controller'];
			}

			$controller = new $controller_class();

			// validate a csrf token if the request is ajax
			if ($runtime->is_ajax) {
				if (isset($runtime->request->args['_csrf_token']))
					$controller->validate_csrf_token((string)$runtime->request->args['_csrf_token']);
				else
					throw new \PaleWhite\ValidationException("all ajax actions require a valid _csrf_token");
			}

			// if (isset($_SERVER['HTTP_X_REQUESTED_WITH']) && (string)$_SERVER['HTTP_X_REQUESTED_WITH'] === 'pale_white/ajax') {
			if ($runtime->is_ajax) {
				// $is_ajax = true;
				$runtime->log_message(get_called_class(), "routing ajax '$runtime->path'");
			} else {
				// $is_ajax = false;
				$runtime->log_message(get_called_class(), "routing '$runtime->path'");
			}
			
			// route the request
			if ($runtime->is_ajax) {
				$controller->route_ajax($runtime->request, $runtime->response);
			} else {
				$controller->route($runtime->request, $runtime->response);
			}

			// if an exception didnt occur, we now got to processing the response and sending it

		} catch (\Exception $e) {
			$runtime->log_exception(get_called_class(), $e);

			// last-chance exception catch
			// since an exception occured, we trash the previous response object,
			// and create our own response to describe the error
			$response = new \PaleWhite\Response();
			$runtime->response = $response;
			$response->status = "500 Server Error";
			if ($runtime->is_ajax) {
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
		$this->send_http_response($runtime->response);

		// after sending the response, we can process scheduled events in the queue
		if ($config['enable_events'])
			$this->process_event_queue();
	}

	public function send_http_response(Response $response) {
		global $config;
		global $runtime;

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
				$runtime->log_message(get_called_class(), "sending file: '" . $response->body->filepath . "'");
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

	public function process_event_queue() {
		global $runtime;
		try {
			$events = \_EventModel::get_list(array(
				'trigger_time' => array('le' => time()),
			));

			foreach ($events as $event) {
				$controller_class = $event->controller_class;
				$controller_event = $event->controller_event;
				$args = $event->args;

				$result = $event->delete();

				if ($result > 0) {
					$runtime->trigger_event($controller_class, $controller_event, $args);
				} else {
					$runtime->log_message(get_called_class(), "notice: failed to lock event [$controller_class:$controller_event]");
				}
			}

		} catch (\Exception $e) {
			$runtime->log_message(get_called_class(), "exception occured while processing event queue!");
			$runtime->log_exception(get_called_class(), $e);
		}
	}
}


