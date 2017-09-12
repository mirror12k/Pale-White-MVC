<?php

namespace PaleWhite;

abstract class Plugin {
	public function on_registered() {
		global $runtime;

		foreach ($this->event_hooks as $event_id)
			$runtime->register_event_hook($event_id, array($this, 'route_event_hook'));

		foreach ($this->action_hooks as $action_id)
			$runtime->register_action_hook($action_id, array($this, 'route_action_hook'));
	}

	public function route_event_hook ($event, array $args) {
		throw new \PaleWhite\InvalidException("undefined event hook routed: '$event'");
	}

	public function route_action_hook ($action, array $args) {
		throw new \PaleWhite\InvalidException("undefined action hook routed: '$action'");
	}
}


