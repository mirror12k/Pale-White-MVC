<?php



namespace PaleWhite;

abstract class Controller {

	public function route (Request $req, Response $res) {}
	public function route_ajax (Request $req, Response $res) {}
	
	public function validate ($type, $value) {
		throw new \PaleWhite\InvalidException("undefined validator requested: '$type'");
	}

	public function action ($action, array $args) {
		throw new \PaleWhite\InvalidException("undefined action requested: '$action'");
	}

	public function log_message($message) {
		$message = (string)$message;
		$message = "[". get_called_class() . "] " . $message;

		global $config;

		error_log($message);
		if ($config['log_file'] !== '')
			error_log(date("[Y-m-d H:i:s]") . " [" . $_SERVER['REMOTE_ADDR'] . "] $message\n", 3, $config['log_file']);
	}

	public function log_exception($exception) {
		if (! $exception instanceof \Exception)
			throw new \PaleWhite\InvalidException("attempt to log_exception non-exception object");

		$this->log_message("a '" . get_class($exception) . "' exception occurred:");
		$this->log_message($exception->getMessage());
		$this->log_message("at " . $exception->getFile() . ":" . $exception->getLine());
		
		foreach ($exception->getTrace() as $trace) {
			$message = $trace['file'] . "(" . $trace['line'] . "): ";
			if (isset($trace['class'])) {
				$message .= $trace['class'] . $trace['type'];
			}
			$message .= $trace['function'];
			$this->log_message(" > $message");
		}
	}

	public function render_template($template_class, array $args) {
		$template = new $template_class();
		return $template->render($args);
	}

	public function route_subcontroller($controller_class, Request $req, Response $res) {
		$controller = new $controller_class();
		return $controller->route($req, $res);
	}

	public function load_model($model_class, array $args) {
		$object = $model_class::get_by($args);

		if ($object === null)
			throw new \PaleWhite\ValidationException("invalid '$model_class'!");
		
		return $object;
	}

	public function create_model($model_class, array $args) {
		$object = $model_class::create($args);

		if ($object === null)
			throw new \PaleWhite\ValidationException("failed to create '$model_class'!");
		
		return $object;
	}

	public function load_file($file_directory, array $args) {
		$file = $file_directory::file($args);

		if ($file === null)
			throw new \PaleWhite\ValidationException("invalid file!");
		
		return $file;
	}

	public function validate_csrf_token($token) {
		if (!hash_equals($_SESSION['pale_white_csrf_token'], $token))
			throw new \PaleWhite\ValidationException("incorrect csrf token");
	}
}


