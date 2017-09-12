<?php

namespace PaleWhite;

abstract class Plugin {
	public function on_registered() {
		global $runtime;

		foreach ($this->event_hooks as $hook_id)
			$runtime->register_event_hook($hook_id, array($this, 'route_event_hook'));

		foreach ($this->action_hooks as $hook_id)
			$runtime->register_action_hook($hook_id, array($this, 'route_action_hook'));

		foreach ($this->controller_route_hooks as $hook_id)
			$runtime->register_controller_route_hook($hook_id, array($this, 'route_path_hook'));

		foreach ($this->controller_ajax_hooks as $hook_id)
			$runtime->register_controller_ajax_hook($hook_id, array($this, 'route_ajax_hook'));
	}

	public function route_event_hook ($event, array $args) {
		throw new \PaleWhite\InvalidException("undefined event hook routed: '$event'");
	}

	public function route_action_hook ($action, array $args) {
		throw new \PaleWhite\InvalidException("undefined action hook routed: '$action'");
	}

	public function route_path_hook ($controller, Request $req, Response $res) {
		throw new \PaleWhite\InvalidException("undefined controller route hook routed: '$controller'");
	}

	public function route_ajax_hook ($controller, Request $req, Response $res) {
		throw new \PaleWhite\InvalidException("undefined controller ajax hook routed: '$controller'");
	}
}


