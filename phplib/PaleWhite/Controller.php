<?php



namespace PaleWhite;

abstract class Controller {

	public function route (Request $req, Response $res) {}
	public function route_ajax (Request $req, Response $res) {}

	public function route_event ($event, array $args) {
		throw new \PaleWhite\InvalidException("undefined event requested: '$event'");
	}
	
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

	public function schedule_event($controller_class, $controller_event, array $args) {
		global $config;
		if (!$config['enable_events'])
			throw new \PaleWhite\InvalidException("attempt to schedule event while events are disabled in config");

		if (isset($args['offset']))
			$offset = (int)$args['offset'];
		else
			$offset = 0;

		if (isset($args['args']))
			$event_args = $args['args'];
		else
			$event_args = array();

		$event_controller_events = $controller_class::$events;
		if (!in_array($controller_event, $event_controller_events))
			throw new \PaleWhite\InvalidException("no event '$controller_event' registered in controller '$controller_class'");

		$event_model = \_EventModel::create(array(
			'trigger_time' => time() + $offset,
			'controller_class' => $controller_class,
			'controller_event' => $controller_event,
			'args' => $event_args,
		));

		$this->log_message("registered event [$controller_class:$controller_event]");

		return $event_model;
	}

	public function set_localization($localization) {
		$localization = (string)$localization;
		if (!preg_match('/\A[a-zA-Z_][a-zA-Z_0-9]*\Z/', $localization))
			throw new \PaleWhite\ValidationException("invalid localization: '$localization'!");

		global $runtime;
		$runtime['current_localization'] = $localization;
	}

	public function get_localized_string($localization_namespace, $field) {
		global $runtime;
		$current_localization = (string)$runtime['current_localization'];
		if ($current_localization === '')
			throw new \PaleWhite\InvalidException("no current localization set!");

		$class = "\\Localization\\$current_localization\\$localization_namespace";
		if (!class_exists($class))
			throw new \PaleWhite\InvalidException("no localization definition found for $localization_namespace:$current_localization");

		return $class::$$field;
	}

	public function validate_csrf_token($token) {
		if (!hash_equals($_SESSION['pale_white_csrf_token'], $token))
			throw new \PaleWhite\ValidationException("incorrect csrf token");
	}

	public function get_session_variable($name) {
		$name = (string)$name;
		if (isset($_SESSION[$name]))
			return $_SESSION[$name];
		else
			return null;
	}

	public function set_session_variable($name, $value) {
		$_SESSION[(string)$name] = $value;
	}
}


