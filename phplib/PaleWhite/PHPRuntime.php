<?php

namespace PaleWhite;

class PHPRuntime {

	public $current_localization;

	public $path;
	public $site_base;
	public $site_url;

	public $is_ajax;
	public $request;
	public $response;
	public $csrf_token;

	public $database;

	public $plugins;
	public $event_hooks = array();

	// ------------------------------------------
	// initialization functions to setup the runtime environment
	// ------------------------------------------

	public function initialize_plugins() {
		global $config;

		$this->plugins = (object)array();
		foreach ($config['plugins'] as $plugin_name => $plugin_config) {
			$plugin_directory = $config['plugins_folder'] . '/' . $plugin_config['plugin_class'];
			require_once "$plugin_directory/includes.php";

			$plugin_class = $plugin_config['plugin_class'];
			$this->register_plugin($plugin_name, new $plugin_class());
		}
	}

	public function initialize_http() {
		global $config;

		$this->current_localization = (string)$config['default_localization'];
		$this->site_base = (string)$config['site_base'];

		$url = parse_url(urldecode($_SERVER['REQUEST_URI']));
		$path = $url['path'];
		$path = substr($path, strlen($config['site_base']));

		$this->path = $path;

		$protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? "https://" : "http://";
		$domain = $_SERVER['HTTP_HOST'];

		$this->site_url = $protocol.$domain;

		if (isset($_SERVER['HTTP_X_REQUESTED_WITH']) && (string)$_SERVER['HTTP_X_REQUESTED_WITH'] === 'pale_white/ajax') {
			$this->is_ajax = true;
		} else {
			$this->is_ajax = false;
		}


		if (isset($_SERVER['CONTENT_TYPE']) && $_SERVER['CONTENT_TYPE'] === 'application/json') {
			// get json input from ajax request
			$input = file_get_contents('php://input');
			$args = json_decode($input, true);
			// $this->log_message("got json request data: " . json_encode($args));

		} else {
			// process any post arguments
			$args = array();
			foreach ($_POST as $k => $v)
				$args[$k] = $v;

			// process any file uploads into args
			foreach ($_FILES as $field => $file_upload)
			{
				// $this->log_message("\$_FILES[$field]: " . json_encode($file_upload));
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
					$file_container = new \PaleWhite\FileUpload($file_upload['name'], $file_upload['tmp_name'], $file_upload['size']);
					$args[$field] = $file_container;
				} elseif ($file_upload['error'] === UPLOAD_ERR_NO_FILE) {
					$args[$field] = null;
				} else {
					throw new \PaleWhite\PaleWhiteException("file upload failed");
				}
			}
			// $this->log_message("got post request data: " . json_encode($args));
		}

		// set up api objects
		$this->request = new \PaleWhite\Request($path, $args);
		$this->response = new \PaleWhite\Response();
	}

	public function initialize_database() {
		global $config;
		$this->database = new \PaleWhite\DatabaseDriver($config['database_config']);
	}

	public function initialize_session() {
		global $config;

		// enable the session
		session_start();
		// $this->log_message("_SESSION: " . json_encode($_SESSION));
		if (!isset($_SESSION['pale_white_csrf_token']))
		{
			$seed = openssl_random_pseudo_bytes(32);
			if ($seed === false)
				throw new \PaleWhite\PaleWhiteException("failed to generate csrf token, not enough entropy");
			$_SESSION['pale_white_csrf_token'] = bin2hex($seed);
		}

		$this->csrf_token = $_SESSION['pale_white_csrf_token'];
	}

	// ------------------------------------------
	// api functions to support compiled code
	// ------------------------------------------

	public function log_message($context, $message) {
		$message = (string)$message;
		$message = "[$context] $message";

		global $config;

		error_log($message);
		if ($config['log_file'] !== '')
			error_log(date("[Y-m-d H:i:s]") . " [" . $_SERVER['REMOTE_ADDR'] . "] $message\n", 3, $config['log_file']);
	}

	public function log_exception($context, $exception) {
		if (! $exception instanceof \Exception)
			throw new \PaleWhite\InvalidException("attempt to log_exception non-exception object");
		
		$this->log_message($context, "an uncaught '" . get_class($exception) . "' exception occurred:");
		$this->log_message($context, $exception->getMessage());
		$this->log_message($context, "at " . $exception->getFile() . ":" . $exception->getLine());
		
		foreach ($exception->getTrace() as $trace) {
			$message = $trace['file'] . "(" . $trace['line'] . "): ";
			if (isset($trace['class'])) {
				$message .= $trace['class'] . $trace['type'];
			}
			$message .= $trace['function'];
			$this->log_message($context, " > $message");
		}
	}

	public function get_localized_string($localization_namespace, $field) {
		global $runtime;
		$current_localization = (string)$runtime->current_localization;
		if ($current_localization === '')
			throw new \PaleWhite\InvalidException("no current localization set!");

		$class = "\\Localization\\$current_localization\\$localization_namespace";
		if (!class_exists($class))
			throw new \PaleWhite\InvalidException("no localization definition found for $localization_namespace:$current_localization");

		return $class::$$field;
	}

	public function schedule_event($context, $controller_class, $controller_event, array $args) {
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

		$this->log_message($context, "registered event [$controller_class:$controller_event]");

		return $event_model;
	}

	public function set_localization($localization) {
		$localization = (string)$localization;
		if (!preg_match('/\A[a-zA-Z_][a-zA-Z_0-9]*\Z/', $localization))
			throw new \PaleWhite\ValidationException("invalid localization: '$localization'!");

		$this->current_localization = $localization;
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

	public function shell_execute($context, array $command_args) {
		if (count($command_args) < 1)
			throw new \PaleWhite\ValidationException("empty shell_execute command");

		$escaped_args = array();
		foreach ($command_args as $arg)
			$escaped_args[] = escapeshellarg($arg);

		$cmd = implode(' ', $escaped_args);
		$cmd = escapeshellcmd($cmd);

		$output = array();
		exec("$cmd 2>&1", $output, $return_value);
		$this->log_message($context, "executed command [$cmd], retval: $return_value");
		$output = implode("\n", $output);

		return (object)array('output' => $output, 'return_value' => $return_value);
	}

	public function trigger_event($controller_class, $controller_event, array $args) {
		if ($controller_class !== 'Runtime')
			$this->log_message(get_called_class(), "event [$controller_class:$controller_event]");

		if (isset($this->event_hooks["$controller_class:$controller_event"]))
			foreach ($this->event_hooks["$controller_class:$controller_event"] as $callback)
				$callback("$controller_class:$controller_event", $args);

		if ($controller_class !== 'Runtime') {
			$controller = new $controller_class();
			$controller->route_event($controller_event, $args);
		}
	}

	public function register_plugin($plugin_name, \PaleWhite\Plugin $plugin_object) {
		if (isset($this->plugins->$plugin_name))
			throw new \PaleWhite\InvalidException("plugin '$plugin_name' has already been loaded");
		else
			$this->plugins->$plugin_name = $plugin_object;

		$plugin_object->on_registered();
	}

	public function register_event_hook($event_id, $callback) {
		if (isset($this->event_hooks["$event_id"]))
			$this->event_hooks["$event_id"][] = $callback;
		else
			$this->event_hooks["$event_id"] = array($callback);
	}
}


