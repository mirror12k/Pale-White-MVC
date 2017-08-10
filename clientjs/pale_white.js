
pale_white = {
	registered_hooks: [],

	onload: function () {
		this.add_hooks(document.body);
	},
	add_hooks: function (dom) {
		this.registered_hooks.forEach(function (hook) {
			var nodes = dom.querySelectorAll(hook.selector);
			for (var i = 0; i < nodes.length; i++) {
				nodes[i].addEventListener(hook.event, hook.callback);
			}
		});
	},
	register_hook: function (selector, event, callback) {
		this.registered_hooks.push({
			selector: selector,
			event: event,
			callback: callback,
		});
	},
};

window.addEventListener('load', function () { pale_white.onload(); });

