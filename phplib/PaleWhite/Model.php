<?php

namespace PaleWhite;

// // php 5.5 doesn't support hash_equals
// // taken from https://secure.php.net/hash_equals
// if(!function_exists('hash_equals')) {
// 	function hash_equals($str1, $str2) {
// 		if(strlen($str1) != strlen($str2)) {
// 			return FALSE;
// 		} else {
// 			$res = $str1 ^ $str2;
// 			$ret = 0;
// 			for($i = strlen($res) - 1; $i >= 0; $i--) {
// 				$ret |= ord($res[$i]);
// 			}
// 			return !$ret;
// 		}
// 	}
// }

global $runtime;

// base model class which provides a lot of magic methods for compiled models
abstract class Model {
	private $_data;
	private $_loaded = array();

	private function __construct(array $data) {
		$this->_data = $data;
	}

	// model access methods
	public function __get($name) {
		if (isset(static::$model_properties[$name])) {
			if (isset(static::$model_submodel_properties[$name]) && !isset($this->_loaded[$name])) {
				$this->_data[$name] = static::get_lazy_loaded_model($name, $this->_data[$name]);
				$this->_loaded[$name] = true;
			}
			return $this->_data[$name];

		} elseif (isset(static::$model_array_properties[$name])) {
			if (!isset($this->_loaded[$name])) {
				$this->_data[$name] = static::load_array_data($this->_data['id'], $name);
				if (isset(static::$model_submodel_properties[$name]))
					$this->_data[$name] = static::get_lazy_loaded_model_array($name, $this->_data[$name]);
				$this->_loaded[$name] = true;
			}
			return $this->_data[$name];

		} elseif (isset(static::$model_map_properties[$name])) {
			if (!isset($this->_loaded[$name])) {
				$this->_data[$name] = static::load_map_data($this->_data['id'], $name);
				if (isset(static::$model_submodel_properties[$name]))
					$this->_data[$name] = static::get_lazy_loaded_model_map($name, $this->_data[$name]);
				$this->_loaded[$name] = true;
			}
			return $this->_data[$name];

		} elseif (isset(static::$model_virtual_properties[$name])) {
			return $this->get_virtual_property($name);

		} else
			throw new \PaleWhite\InvalidException(
					"attempted to get undefined model property '$name' in model class: " . get_called_class());
	}

	public function get_virtual_property($name) {
		throw new \PaleWhite\InvalidException(
				"undefined virtual model property '$name' in model class: " . get_called_class());
	}

	public function __set($name, $value) {
		if ($name === 'id') {
			throw new \PaleWhite\InvalidException(
					"attempted to set model property 'id' in model class: " . get_called_class());
		} elseif (isset(static::$model_properties[$name])) {
			$this->_data[$name] = $value;
			$this->update_fields(array($name => $value));
		} else {
			throw new \PaleWhite\InvalidException(
					"attempted to set undefined model property '$name' in model class: " . get_called_class());
		}
	}

	public function add($array_name, $value) {
		if (!isset(static::$model_array_properties[$array_name]))
			throw new \PaleWhite\InvalidException(
					"attempted to add() undefined model property '$array_name' in model class: " . get_called_class());

		global $runtime;
		$query = $runtime->database->insert()
				->table(static::$table_name . '__array_property__' . $array_name)
				->values(array('parent_id' => $this->_data['id'], 'value' => static::cast_to_store($array_name, $value)));

		$result = $query->fetch();
		if ($result === true) {
			// write value to loaded data
			if (isset($this->_loaded[$array_name]))
				$this->_data[$array_name][] = $value;

			return true;
		} else {
			return false;
		}
	}

	public function remove($array_name, $value, $limit=null) {
		if (!isset(static::$model_array_properties[$array_name]))
			throw new \PaleWhite\InvalidException(
					"attempted to remove() undefined model property '$array_name' in model class: " . get_called_class());

		global $runtime;
		$query = $runtime->database->delete()
				->table(static::$table_name . '__array_property__' . $array_name)
				->where(array('parent_id' => $this->_data['id'], 'value' => static::cast_to_store($array_name, $value)));

		if (isset($limit))
			$query->limit($limit);

		$result = $query->fetch();
		return $result;
	}

	public function contains($array_name, $value) {
		if (!isset(static::$model_array_properties[$array_name]))
			throw new \PaleWhite\InvalidException(
					"attempted to contains() undefined model property '$array_name' in model class: " . get_called_class());

		global $runtime;
		$query = $runtime->database->select()
				->table(static::$table_name . '__array_property__' . $array_name)
				->where(array('parent_id' => $this->_data['id'], 'value' => static::cast_to_store($array_name, $value)));

		$result = $query->fetch();
		return $result > 0;
	}

	public function list_array($array_name, $args = array()) {
		if (!isset(static::$model_array_properties[$array_name]))
			throw new \PaleWhite\InvalidException(
					"attempted to list_array() undefined model property '$array_name' in model class: " . get_called_class());

		// parse args
		$list_array_args = array();
		foreach ($args as $name => $value) {
			if ($name === '_limit')
				$list_array_args['limit'] = $value;
			elseif ($name === '_offset')
				$list_array_args['offset'] = $value;
			elseif ($name === '_order')
				$list_array_args['order'] = $value;
			else
				throw new \PaleWhite\InvalidException("invalid list argument: '$name', in model class: " . get_called_class());
		}

		$result_array = static::load_array_data($this->_data['id'], $array_name, $list_array_args);
		if (isset(static::$model_submodel_properties[$array_name]))
			$result_array = static::get_lazy_loaded_model_array($array_name, $result_array);

		return $result_array;
	}

	public function count_array($array_name, $args = array()) {
		if (!isset(static::$model_array_properties[$array_name]))
			throw new \PaleWhite\InvalidException(
					"attempted to count_array() undefined model property '$array_name' in model class: " . get_called_class());

		// parse args
		$count_array_args = array();
		foreach ($args as $name => $value) {
			if ($name === '_limit')
				$count_array_args['limit'] = $value;
			elseif ($name === '_offset')
				$count_array_args['offset'] = $value;
			elseif ($name === '_order')
				$count_array_args['order'] = $value;
			else
				throw new \PaleWhite\InvalidException("invalid list argument: '$name', in model class: " . get_called_class());
		}

		global $runtime;
		$query = $runtime->database->count()
				->table(static::$table_name . '__array_property__' . $array_name)
				->where(array('parent_id' => $this->_data['id']));

		if (isset($count_array_args['limit']))
			$query->limit($count_array_args['limit']);
		if (isset($count_array_args['offset']))
			$query->offset($count_array_args['offset']);
		if (isset($count_array_args['order']))
			$query->order($count_array_args['order']);

		$result = $query->fetch();

		return $result;
	}

	public function map_get($map_name, $key) {
		if (!isset(static::$model_map_properties[$map_name]))
			throw new \PaleWhite\InvalidException(
					"attempted to map_get() undefined model property '$map_name' in model class: " . get_called_class());

		// return the cached value if we have it loaded already
		if (isset($this->_loaded[$map_name]))
			return isset($this->_data[$map_name][$key]) ? $this->_data[$map_name][$key] : null;

		// query the database for this entry
		global $runtime;
		$query = $runtime->database->select()
				->table(static::$table_name . '__map_property__' . $map_name)
				->where(array('parent_id' => $this->_data['id'], 'map_key' => $key));

		$result = $query->fetch();
		if (count($result) > 0) {
			$value = $result[0]['value'];
			if (isset(static::$model_submodel_properties[$map_name]))
				$value = static::get_lazy_loaded_model($name, $value);
			return $value;
		} else {
			return null;
		}
	}

	public function map_add($map_name, $key, $value) {
		if (!isset(static::$model_map_properties[$map_name]))
			throw new \PaleWhite\InvalidException(
					"attempted to map_add() undefined model property '$map_name' in model class: " . get_called_class());

		global $runtime;
		$query = $runtime->database->insert()
				->table(static::$table_name . '__map_property__' . $map_name)
				->values(array(
					'parent_id' => $this->_data['id'],
					'map_key' => $key,
					'value' => static::cast_to_store($map_name, $value),
				));

		$result = $query->fetch();
		if ($result === true) {
			// write value to loaded data
			if (isset($this->_loaded[$map_name]))
				$this->_data[$map_name][$key] = $value;

			return true;
		} else {
			return false;
		}
	}

	public function map_remove($map_name, $key) {
		if (!isset(static::$model_map_properties[$map_name]))
			throw new \PaleWhite\InvalidException(
					"attempted to map_remove() undefined model property '$map_name' in model class: " . get_called_class());

		global $runtime;
		$query = $runtime->database->delete()
				->table(static::$table_name . '__map_property__' . $map_name)
				->values(array(
					'parent_id' => $this->_data['id'],
					'map_key' => $key,
				));

		if (isset($limit))
			$query->limit($limit);

		$result = $query->fetch();
		return $result;
	}

	public function map_contains($map_name, $key) {
		if (!isset(static::$model_map_properties[$map_name]))
			throw new \PaleWhite\InvalidException(
					"attempted to map_contains() undefined model property '$map_name' in model class: " . get_called_class());

		global $runtime;
		$query = $runtime->database->count()
				->table(static::$table_name . '__map_property__' . $map_name)
				->where(array('parent_id' => $this->_data['id'], 'map_key' => $key));

		$result = $query->fetch();
		return $result > 0;
	}

	public function map_list_keys($map_name, $args = array()) {
		if (!isset(static::$model_map_properties[$map_name]))
			throw new \PaleWhite\InvalidException(
					"attempted to map_list() undefined model property '$map_name' in model class: " . get_called_class());

		// parse args
		$list_array_args = array();
		foreach ($args as $name => $value) {
			if ($name === '_limit')
				$list_array_args['limit'] = $value;
			elseif ($name === '_offset')
				$list_array_args['offset'] = $value;
			elseif ($name === '_order')
				$list_array_args['order'] = $value;
			else
				throw new \PaleWhite\InvalidException("invalid list argument: '$name', in model class: " . get_called_class());
		}

		$result_array = static::load_map_data($this->_data['id'], $map_name, $list_array_args);

		$map_keys = array();
		foreach ($result_array as $key => $value)
			$map_keys[] = $key;

		return $map_keys;
	}

	public function map_list($map_name, $args = array()) {
		if (!isset(static::$model_map_properties[$map_name]))
			throw new \PaleWhite\InvalidException(
					"attempted to map_list() undefined model property '$map_name' in model class: " . get_called_class());

		// parse args
		$list_array_args = array();
		foreach ($args as $name => $value) {
			if ($name === '_limit')
				$list_array_args['limit'] = $value;
			elseif ($name === '_offset')
				$list_array_args['offset'] = $value;
			elseif ($name === '_order')
				$list_array_args['order'] = $value;
			else
				throw new \PaleWhite\InvalidException("invalid list argument: '$name', in model class: " . get_called_class());
		}

		$result_array = static::load_map_data($this->_data['id'], $map_name, $list_array_args);
		if (isset(static::$model_submodel_properties[$map_name]))
			$result_array = static::get_lazy_loaded_model_map($map_name, $result_array);

		return $result_array;
	}

	public function map_count($map_name, $args = array()) {
		if (!isset(static::$model_map_properties[$map_name]))
			throw new \PaleWhite\InvalidException(
					"attempted to map_count() undefined model property '$map_name' in model class: " . get_called_class());

		// parse args
		$count_array_args = array();
		foreach ($args as $name => $value) {
			if ($name === '_limit')
				$count_array_args['limit'] = $value;
			elseif ($name === '_offset')
				$count_array_args['offset'] = $value;
			elseif ($name === '_order')
				$count_array_args['order'] = $value;
			else
				throw new \PaleWhite\InvalidException("invalid list argument: '$name', in model class: " . get_called_class());
		}

		global $runtime;
		$query = $runtime->database->count()
				->table(static::$table_name . '__map_property__' . $map_name)
				->where(array('parent_id' => $this->_data['id']));

		if (isset($count_array_args['limit']))
			$query->limit($count_array_args['limit']);
		if (isset($count_array_args['offset']))
			$query->offset($count_array_args['offset']);
		if (isset($count_array_args['order']))
			$query->order($count_array_args['order']);

		$result = $query->fetch();

		return $result;
	}

	public function matches_hashed_field($name, $value) {
		if (!isset(static::$model_properties[$name]) || static::$model_properties[$name] !== 'salted_sha256')
			throw new \PaleWhite\InvalidException(
					"attempt to match invalid hashed field on '$name' in model class: " . get_called_class());

		$existing_hash = $this->_data[$name];
		$salt = explode('/', $existing_hash)[0];
		$compare_hash = static::salt_and_hash_string($value, $salt);

		return hash_equals($existing_hash, $compare_hash);
	}

	public function delete() {
		$this->on_delete();

		global $runtime;
		$query = $runtime->database->delete()
				->table(static::$table_name)
				->where(array('id' => $this->_data['id']));
		$result = $query->fetch();

		unset(static::$_model_cache['id'][$this->_data['id']]);

		foreach (static::$model_array_properties as $field => $field_type) {
			// $loaded[$field] = static::load_array_data($data['id'], $field);

			$query = $runtime->database->delete()
					->table(static::$table_name . '__array_property__' . $field)
					->where(array('parent_id' => $this->_data['id']));
			$query->fetch();
		}

		foreach (static::$model_map_properties as $field => $field_type) {
			$query = $runtime->database->delete()
					->table(static::$table_name . '__map_property__' . $field)
					->where(array('parent_id' => $this->_data['id']));
			$query->fetch();
		}

		return $result;
	}

	public function on_create() {}
	public function on_delete() {}

	// model static access/creation methods
	public static function get_by_id($id) {
		// return cached item if available
		if (isset(static::$_model_cache['id'][$id]))
			return static::$_model_cache['id'][$id];

		return static::get_by(array('id' => $id));
	}

	private static function get_multiple_by_id(array $ids) {
		// // return cached item if available
		// if (isset(static::$_model_cache['id'][$id]))
		// 	return static::$_model_cache['id'][$id];

		$ids_list = array();
		foreach ($ids as $key => $id) {
			$ids_list[] = $id;
		}

		// retrieve the items as a list
		$items = static::get_list(array('id' => $ids_list));
		// order the items by id
		$items_by_id = array();
		foreach ($items as $item)
			$items_by_id[$item->id] = $item;

		// reorder the items by the given ids_list order
		$results = array();
		foreach ($ids as $key => $id)
			$results[$key] = isset($items_by_id[$id]) ? $items_by_id[$id] : null;

		return $results;
	}

	public static function get_by(array $values) {
		$values = static::store_data($values);

		global $runtime;
		$query = $runtime->database->select()
				->table(static::$table_name)
				->where($values)
				->limit(1);

		$result = static::get_by_query($query);

		if (count($result) === 0)
			return null;
		else
			return $result[0];
	}

	public static function get_list(array $values = array()) {
		// parse out any special values
		$where_values = array();
		foreach ($values as $name => $value) {
			if ($name === '_limit')
				$limit = $value;
			elseif ($name === '_offset')
				$offset = $value;
			elseif ($name === '_order')
				$order = $value;
			else
				$where_values[$name] = $value;
		}

		// convert to database-safe format
		$where_values = static::store_data($where_values);

		global $runtime;
		// build the query
		$query = $runtime->database->select()
				->table(static::$table_name)
				->where($where_values);

		if (isset($limit))
			$query->limit($limit);
		if (isset($offset))
			$query->offset($offset);
		if (isset($order))
			$query->order($order);

		$result = static::get_by_query($query);

		return $result;
	}

	public static function count(array $values = array()) {
		// parse out any special values
		$where_values = array();
		foreach ($values as $name => $value) {
			if ($name === '_limit')
				$limit = $value;
			elseif ($name === '_offset')
				$offset = $value;
			elseif ($name === '_order')
				$order = $value;
			else
				$where_values[$name] = $value;
		}

		// convert to database-safe format
		$where_values = static::store_data($where_values);

		global $runtime;
		// build the query
		$query = $runtime->database->count()
				->table(static::$table_name)
				->where($where_values);

		if (isset($limit))
			$query->limit($limit);
		if (isset($offset))
			$query->offset($offset);
		if (isset($order))
			$query->order($order);

		$result = $query->fetch();

		return $result;
	}

	public static function get_by_query(DatabaseQuery $query) {
		$result = $query->fetch();

		$objects = array();
		foreach ($result as $data) {
			$data = static::load_data($data);
			$objects[] = new static($data);
		}

		return $objects;
	}

	public static function create(array $data = array()) {
		$data = static::store_data($data);

		$item_fields = array();
		$array_fields = array();
		foreach ($data as $field => $value) {
			if (isset(static::$model_properties[$field]))
				$item_fields[$field] = $value;
			elseif (isset(static::$model_array_properties[$field]))
				$array_fields[$field] = $value;
			else
				throw new \PaleWhite\InvalidException(
						"attempted to create undefined model property '$field' in model class: " . get_called_class());
		}

		global $runtime;
		$query = $runtime->database->insert()
				->table(static::$table_name)
				->values($item_fields);
		$result = $query->fetch();

		if ($result !== TRUE)
			throw new \PaleWhite\ModelException(get_called_class(),
					"database failed to create object");

		$obj_id = $runtime->database->insert_id;
		$obj = static::get_by_id($obj_id);
		if ($obj === null)
			throw new \PaleWhite\ModelException(get_called_class(),
					"fatal error creating object (id $obj_id)");

		// have the object update the array fields itself
		foreach ($array_fields as $field => $value) {
			$obj->$field = $value;
		}

		$obj->on_create();

		return $obj;
	}

	private static function load_data(array $data) {
		$loaded = array();
		// error_log("debug load_data on " . get_called_class() . ": " . json_encode($data));
		foreach ($data as $field => $value) {
			$loaded[$field] = static::cast_from_store($field, $value);
		}
		// foreach (static::$model_array_properties as $field => $field_type) {
		// 	$loaded[$field] = static::load_array_data($data['id'], $field);
		// }
		return $loaded;
	}

	private static function load_array_data($id, $field, $args = array()) {
		global $runtime;
		$query = $runtime->database->select()
				->table(static::$table_name . '__array_property__' . $field)
				->fields(array('value'))
				->where(array('parent_id' => $id));

		if (isset($args['limit']))
			$query->limit($args['limit']);
		if (isset($args['offset']))
			$query->offset($args['offset']);
		if (isset($args['order']))
			$query->order($args['order']);

		$result = $query->fetch();

		$array = array();
		foreach ($result as $row)
			$array[] = static::cast_from_store($field, $row['value']);

		return $array;
	}

	private static function load_map_data($id, $field, $args = array()) {
		global $runtime;
		$query = $runtime->database->select()
				->table(static::$table_name . '__map_property__' . $field)
				->fields(array('map_key', 'value'))
				->where(array('parent_id' => $id));

		if (isset($args['limit']))
			$query->limit($args['limit']);
		if (isset($args['offset']))
			$query->offset($args['offset']);
		if (isset($args['order']))
			$query->order($args['order']);

		$result = $query->fetch();

		$array = array();
		foreach ($result as $row)
			$array[$row['map_key']] = static::cast_from_store($field, $row['value']);

		return $array;
	}

	private static function store_data(array $data) {
		$stored = array();
		foreach ($data as $field => $value) {
			if (isset(static::$model_properties[$field]))
				$stored[$field] = static::cast_to_store($field, $value);
			elseif (isset(static::$model_array_properties[$field]))
				$stored[$field] = static::store_array_data($field, $value);
			else
				throw new \PaleWhite\InvalidException(
						"attempted to cast undefined model property '$field' in model class: " . get_called_class());
		}
		return $stored;
	}

	private static function store_array_data($field, $value) {
		$stored = array();
		foreach ($value as $item)
			$stored[] = static::cast_to_store($field, $item);
		return $stored;
	}

	private static function store_map_data($field, $value) {
		$stored = array();
		foreach ($value as $key => $item)
			$stored[$key] = static::cast_to_store($field, $item);
		return $stored;
	}

	public static function cast_to_store($name, $value) {
		if (isset(static::$model_submodel_properties[$name])) {
			if ($value instanceof \PaleWhite\Model) {
				$value = $value->id;
			} elseif ($value === null) {
				$value = 0;
			}
		} elseif (isset(static::$model_file_properties[$name])) {
			if ($value instanceof \PaleWhite\FileDirectoryFile) {
				$value = $value->filename;
			} elseif ($value === null) {
				$value = '';
			}
		} elseif (isset(static::$model_json_properties[$name])) {
			if (is_array($value) || is_object($value)) {
				$value = json_encode($value);
			} elseif ($value === null) {
				$value = '';
			} else {
				$value = (string)$value;
			}
		} elseif (isset(static::$model_properties[$name]) && static::$model_properties[$name] === 'salted_sha256') {
			$value = (string)$value;
			$value = static::salt_and_hash_string($value);
		}
		return $value;
	}

	public static function cast_from_store($name, $value) {
		if (isset(static::$model_file_properties[$name]))
		{
			$class = static::$model_file_properties[$name];
			$value = (string)$value;
			$value = ($value === "" ? null : $class::load_file($value));
		} elseif (isset(static::$model_json_properties[$name])) {
			if ($value === '') {
				$value = null;
			} else {
				$value = json_decode($value, true);
			}
		}

		return $value;
	}

	public static function salt_and_hash_string($str, $salt=null) {
		$str = (string)$str;
		if ($salt === null) {
			$salt = openssl_random_pseudo_bytes(32);
			if ($salt === false)
				throw new \PaleWhite\PaleWhiteException("failed to generate salt, not enough entropy");
			$salt = bin2hex($salt);
		}
		$hash = hash('sha256', "$salt$str");
		return "$salt/$hash";
	}

	// public static function cast_model_from_store($name, $value) {
	// 	if (!isset(static::$model_submodel_properties[$name]))
	// 		throw new \PaleWhite\InvalidException(
	// 	"attempt to cast model from store on non-model property '$name' in model class: "
	// 				. get_called_class());

	// 	$class = static::$model_submodel_properties[$name];
	// 	$value = (int)$value;
	// 	$value = $value === 0 ? null : $class::get_by_id((int)$value);
	// 	return $value;
	// }

	private static function get_lazy_loaded_model($name, $value) {
		if (!isset(static::$model_submodel_properties[$name]))
			throw new \PaleWhite\InvalidException(
					"attempt to lazy load non-model property '$name' in model class: " . get_called_class());

		$class = static::$model_submodel_properties[$name];
		$value = (int)$value;
		return $value === 0 ? null : $class::get_by_id($value);
		// if (is_int($value) or is_string($value)) {
		// 	$value = static::cast_model_from_store($name, $value);
		// }
		// return $value;
	}

	private static function get_lazy_loaded_model_array($name, $value) {
		if (!isset(static::$model_submodel_properties[$name]))
			throw new \PaleWhite\InvalidException(
					"attempt to lazy load non-model property '$name' in model class: " . get_called_class());
		
		if (count($value) === 0)
			return array();
		$class = static::$model_submodel_properties[$name];
		return $class::get_multiple_by_id($value);
	}

	private static function get_lazy_loaded_model_map($name, $value) {
		if (!isset(static::$model_map_properties[$name]))
			throw new \PaleWhite\InvalidException(
					"attempt to lazy load non-model property '$name' in model class: " . get_called_class());
		
		if (count($value) === 0)
			return array();
		$class = static::$model_map_properties[$name];
		return $class::get_multiple_by_id($value);
	}

	// private static function get_lazy_loaded_file($name, $value) {
	// 	if (!isset(static::$model_file_properties[$name]))
	// 		throw new \PaleWhite\InvalidException(
	// 	"attempt to lazy load non-file property '$name' in model class: " . get_called_class());

	// 	$class = static::$model_file_properties[$name];
	// 	$value = (string)$value;
	// 	return $value === "" ? null : $class::load_file($value);
	// }

	// private static function get_lazy_loaded_file_array($name, $value) {
	// 	if (!isset(static::$model_file_properties[$name]))
	// 		throw new \PaleWhite\InvalidException(
	// "attempt to lazy load non-file property '$name' in model class: " . get_called_class());
		
	// 	$class = static::$model_file_properties[$name];

	// 	$files = array();
	// 	foreach ($value as $filepath)
	// 		$files[] = $value === "" ? null : $class::load_file($value);

	// 	return $files;
	// }

	private function update_fields(array $values) {

		$item_fields = array();
		$array_fields = array();
		foreach ($values as $field => $value) {
			if (isset(static::$model_properties[$field]))
				$item_fields[$field] = $value;
			elseif (isset(static::$model_array_properties[$field]))
				$array_fields[$field] = $value;
			else
				throw new \PaleWhite\InvalidException(
						"attempted to update undefined model property '$field' in model class: " . get_called_class());
		}


		if (count($item_fields) > 0) {
			$item_fields = static::store_data($item_fields);

			global $runtime;
			$query = $runtime->database->update()
					->table(static::$table_name)
					->values($item_fields)
					->where(array('id' => $this->_data['id']));
			$query->fetch();
		}

		foreach ($array_fields as $field => $value)
			$this->update_array_field($field, $value);
	}

	private function update_array_field($field, $value) {
		$value = static::store_array_data($field, $value);

		global $runtime;
		$delete_query = $runtime->database->delete()
				->table(static::$table_name . '__array_property__' . $field)
				->where(array('parent_id' => $this->_data['id']));
		$delete_query->fetch();

		foreach ($value as $item) {
			$insert_query = $runtime->database->insert()
					->table(static::$table_name . '__array_property__' . $field)
					->values(array('parent_id' => $this->_data['id'], 'value' => $item));
			$insert_query->fetch();
		}
	}
}


