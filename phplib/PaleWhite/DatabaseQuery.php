<?php


namespace PaleWhite;

class DatabaseQuery {
	public function __construct(DatabaseDriver $db, $query_type) {
		$this->db = $db;
		$this->query_type = $query_type;
		$this->query_args = array();
	}

	public function fields(array $fields) {
		$this->query_args['fields'] = $fields;
		return $this;
	}

	public function table($table) {
		$this->query_args['table'] = (string)$table;
		return $this;
	}

	public function values(array $args) {
		if (!isset($this->query_args['values']))
			$this->query_args['values'] = array();
		foreach ($args as $field => $value) {
			$this->query_args['values'][$field] = $value;
		}
		return $this;
	}

	public function where(array $args) {
		if (!isset($this->query_args['where']))
			$this->query_args['where'] = array();
		foreach ($args as $field => $value) {
			$this->query_args['where'][$field] = $value;
		}
		return $this;
	}

	public function limit($limit) {
		$this->query_args['limit'] = (int)$limit;
		return $this;
	}

	public function offset($offset) {
		$this->query_args['offset'] = (int)$offset;
		return $this;
	}

	public function order($order) {

		if ($order === 'ascending' || $order === 'descending')
			$this->query_args['order'] = (string)$order;
		elseif (is_object($order) || is_array($order))
			$this->query_args['order'] = $order;
		else
			throw new \PaleWhite\InvalidException('invalid row order: "$order"');

		return $this;
	}

	public function compile() {
		if (!isset($this->query_args['table']))
			throw new \PaleWhite\InvalidException("'table' property not set in database query");

		$table_name = '`' . $this->db->escape_string($this->query_args['table']) . '`';

		if ($this->query_type === 'select') {
			$query = 'SELECT';

			if (isset($this->query_args['fields'])) {
				$fields = array();
				foreach ($this->query_args['fields'] as $field) {
					$fields[] = "$table_name.`" . $this->db->escape_string($field) . '`';
				}
			} else {
				$fields = array("$table_name.*");
			}
			$query .= ' ' . implode(', ', $fields);

			$query .= " FROM $table_name";

			if (isset($this->query_args['where'])) {
				$query .= $this->compile_where_clause($this->query_args['where']);
			}

			if (isset($this->query_args['order'])) {
				$query .= $this->compile_order_clause($this->query_args['order']);
			}

			$query .= $this->compile_limit_clause();

			return $query;

		} elseif ($this->query_type === 'count') {
			$query = 'SELECT';

			$fields = array('COUNT(*)');
			$query .= ' ' . implode(', ', $fields);

			$query .= " FROM $table_name";

			if (isset($this->query_args['where'])) {
				$query .= $this->compile_where_clause($this->query_args['where']);
			}

			if (isset($this->query_args['order'])) {
				$query .= $this->compile_order_clause($this->query_args['order']);
			}

			$query .= $this->compile_limit_clause();

			return $query;

		} elseif ($this->query_type === 'insert') {
			$query = 'INSERT';

			$query .= " INTO $table_name";

			if (isset($this->query_args['values'])) {
				$fields = array();
				foreach ($this->query_args['values'] as $field => $value) {
					$fields[] = '`' . $this->db->escape_string($field) . '`';
				}
				$query .= ' (' . implode(', ', $fields) . ')';

				$values = array();
				foreach ($this->query_args['values'] as $field => $value) {
					if (is_string($value)) {
						$value = '\'' . $this->db->escape_string($value) . '\'';
					} elseif (is_numeric($value)) {
						$value = "$value";
					} else {
						throw new \PaleWhite\InvalidException("invalid value type for where field $field: " . gettype($value));
					}
					$values[] = $value;
				}
				$query .= ' VALUES (' . implode(', ', $values) . ')';
			}

			return $query;

		} elseif ($this->query_type === 'update') {
			$query = "UPDATE $table_name";

			if (isset($this->query_args['values'])) {
				$values = array();
				foreach ($this->query_args['values'] as $field => $value) {
					$field = '`' . $this->db->escape_string($field) . '`';
					if (is_string($value)) {
						$value = '\'' . $this->db->escape_string($value) . '\'';
					} elseif (is_numeric($value)) {
						$value = "$value";
					} elseif ((is_array($value) || is_object($value)) && isset($value['increment'])) {
						$value = "$field + " . (int)$value['increment'];
					} else {
						throw new \PaleWhite\InvalidException("invalid value type for where field $field: " . gettype($value));
					}
					$values[] = "$field = $value";
				}
				$query .= ' SET ' . implode(', ', $values);
			}

			if (isset($this->query_args['where'])) {
				$query .= $this->compile_where_clause($this->query_args['where']);
			}

			if (isset($this->query_args['order'])) {
				$query .= $this->compile_order_clause($this->query_args['order']);
			}

			$query .= $this->compile_limit_clause();

			return $query;
		} elseif ($this->query_type === 'delete') {
			$query = 'DELETE';

			$query .= " FROM $table_name";

			if (isset($this->query_args['where'])) {
				$query .= $this->compile_where_clause($this->query_args['where']);
			}

			if (isset($this->query_args['order'])) {
				$query .= $this->compile_order_clause($this->query_args['order']);
			}

			$query .= $this->compile_limit_clause();

			return $query;

		} else {
			throw new \PaleWhite\InvalidException("invalid query_type: " . $this->query_type);
		}
	}

	public function compile_where_clause($where_clause)
	{
		# parse out joins first
		$joins = array();
		foreach ($where_clause as $field => $value) {
			if ((is_array($value) || is_object($value)) && isset($value['on'])) {
				if (count($value['on']) < 1)
					throw new \PaleWhite\InvalidException("empty 'on' clause for where join '$field'");

				$joins[$field] = $value['on'];
			}
		}

		if (count($joins) > 0)
			$prefix = '`' . $this->db->escape_string($this->query_args['table']) . '`.';
		else
			$prefix = '';

		$fields = $this->compile_where_clause_fields($prefix, $where_clause);

		foreach ($where_clause as $field => $value) {
			if ((is_array($value) || is_object($value)) && isset($value['on']) && isset($value['where'])) {
				$join_table_prefix = '`' . $this->db->escape_string($field) . '`.';
				$fields = array_merge($fields, $this->compile_where_clause_fields($join_table_prefix, $value['where']));
			}
		}

		$inner_join_clause = ' ';
		foreach ($joins as $join_table => $join_conditions) {
			$join_table_escaped = '`' . $this->db->escape_string($join_table) . '`';

			$compiled_join_conditions = array();
			foreach ($join_conditions as $join_field => $compare_value) {
				$left = $join_table_escaped . '.' . '`' . $this->db->escape_string($join_field) . '`';
				if ((is_array($compare_value) || is_object($compare_value)) && isset($compare_value['field'])) {
					$right = $prefix . '`' . $this->db->escape_string($compare_value['field']) . '`';
				} elseif (is_string($compare_value)) {
					$right = '\'' . $this->db->escape_string($compare_value) . '\'';
				} elseif (is_numeric($compare_value)) {
					$right = "$compare_value";
				} else {
					throw new \PaleWhite\InvalidException("invalid value type for where field $join_table.$join_field: " . gettype($compare_value));
				}

				$compiled_join_conditions[] = "$left = $right";
			}
			$compiled_join_conditions = implode(' AND ', $compiled_join_conditions);

			$inner_join_clause .= "LEFT JOIN $join_table_escaped ON $compiled_join_conditions ";
		}

		if (count($fields) > 0)
			return " $inner_join_clause WHERE " . implode(' AND ', $fields) . ' ';
		elseif (count($joins) > 0)
			return " $inner_join_clause ";
		else
			return ' ';
	}

	public function compile_where_clause_fields($prefix, $where_fields) {
		$fields = array();
		foreach ($where_fields as $field => $value) {
			$field = '`' . $this->db->escape_string($field) . '`';
			if ((is_array($value) || is_object($value)) && (
					isset($value['lt']) ||
					isset($value['le']) ||
					isset($value['gt']) ||
					isset($value['ge'])
					)) {
				if (isset($value['lt'])) {
					$comparison = '<';
					$value = $value['lt'];
				} elseif (isset($value['le'])) {
					$comparison = '<=';
					$value = $value['le'];
				} elseif (isset($value['gt'])) {
					$comparison = '>';
					$value = $value['gt'];
				} elseif (isset($value['ge'])) {
					$comparison = '>=';
					$value = $value['ge'];
				}

				if (is_string($value)) {
					$value = '\'' . $this->db->escape_string($value) . '\'';
				} elseif (is_numeric($value)) {
					$value = "$value";
				} else {
					throw new \PaleWhite\InvalidException("invalid value type for where field $field: " . gettype($value));
				}
				$fields[] = "$prefix$field $comparison $value";

			} elseif ((is_array($value) || is_object($value)) && isset($value['on'])) {
				# ignore

			} elseif (is_array($value)) {
				$escaped_values = array();
				foreach ($value as $subvalue) {
					if (is_string($subvalue)) {
						$escaped_values[] = '\'' . $this->db->escape_string($subvalue) . '\'';
					} elseif (is_numeric($subvalue)) {
						$escaped_values[] = "$subvalue";
					} else {
						throw new \PaleWhite\InvalidException("invalid value type for where field $field: " . gettype($value));
					}
				}
				if (count($escaped_values) < 1)
					throw new \PaleWhite\InvalidException("empty value list for where field $field!");

				$escaped_values = implode(",", $escaped_values);
				$fields[] = "$prefix$field IN ($escaped_values)";

			} else {
				if (is_string($value)) {
					$value = '\'' . $this->db->escape_string($value) . '\'';
				} elseif (is_numeric($value)) {
					$value = "$value";
				} else {
					throw new \PaleWhite\InvalidException("invalid value type for where field $field: " . gettype($value));
				}
				$fields[] = "$prefix$field = $value";
			}
		}

		return $fields;
	}

	public function compile_order_clause ($order_clause) {

		if ($order_clause === 'ascending' || $order_clause === 'descending') {
			$table_name = $this->query_args['table'];
			$field = 'id';
			$order = $order_clause;
		} else {
			foreach ($order_clause as $key => $value)
			{
				if (is_array($value) || is_object($value)) {
					foreach ($value as $key2 => $value2) {
						$table_name = $key;
						$field = $key2;
						$order = $value2;
					}
				} else {
					$table_name = $this->query_args['table'];
					$field = $key;
					$order = $value;
				}
			}
		}

		$compiled_field = '`' . $this->db->escape_string($table_name) . '`.`' . $this->db->escape_string($field) . '`';

		if ($order === 'ascending')
			$order = "ASC";
		else
			$order = "DESC";

		return " ORDER BY $compiled_field $order ";
	}

	public function compile_limit_clause () {
		if (isset($this->query_args['limit'])) {
			if (isset($this->query_args['offset']))
				return ' LIMIT ' . $this->query_args['offset'] . ',' . $this->query_args['limit'] . ' ';
			else
				return ' LIMIT ' . $this->query_args['limit'] . ' ';
		} else {
			return ' ';
		}
	}

	public function fetch() {
		$result = $this->db->query($this);

		if ($this->query_type === 'select') {
			$data = array();
			for ($i = 0; $i < $result->num_rows; $i++) {
				$data[] = $result->fetch_assoc();
			}
			$result->free();
		} elseif ($this->query_type === 'count') {
			$data = $result->fetch_array();
			$data = (int)$data[0];
			$result->free();
		} else {
			$data = $result;
		}
		return $data;
	}
}

