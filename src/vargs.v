module vargs

import strconv
import x.json2 { Any }
import json

struct Field {
pub mut:
	name string 		// name of the argument
	short ?string		// short tag to set this argument
	long ?string		// long tag to set this argument. If not set, it will be the same as the name
	default ?Any	// default value for this argument. If not set, it will be nulled Option
	args ?int				// The placement of this arg in the args list. If set, long and short will be ignored.
	typ int 				// The type of this argument.
	is_array bool		// If this argument is an array or not.
	required bool		// If this argument is required or not.
}

pub fn parse[T](raw_args []string) T {
	fields := find_fields[T]()

	values := retrieve_args(fields, raw_args)
	return json.decode(T, values.str()) or { panic("Can't parse ${values.str()} to ${T.name}") }
}

fn find_fields[T]() []Field {
	mut fields := []Field{}

	$for field in T.fields {
		mut f := Field{
			name: field.name,
			required: !field.is_option,
			typ: field.typ,
			is_array: field.is_array,
		}
		for attr in field.attrs {
		  raw_attr := attr.split(": ")
			key := raw_attr[0]
			value := raw_attr[1]
			match key {
				"short" { f.short = value }
				"long" { f.long = value }
				"default" { f.default = parse_to_typ(f.typ, value, f.is_array) }
				"args" { f.args = strconv.atoi(value) or { panic("Can't parse ${value} to int") } }
				else {}
			}
		}
		if f.long == none && f.args == none {
			f.long = f.name
		}
		fields << f
	}

	return fields
}

fn retrieve_args(fields []Field, raw_args []string) map[string]Any {
	mut values := map[string]Any{}

	mut arg_index := 0
	mut positional_fields := fields.filter(|x| x.args != none)
	positional_fields.sort(|x, y| x.args! < y.args!)

	mut i := 1
	for {
		if i >= raw_args.len {
			break
		}

		arg := raw_args[i]
		mut field := Field{}
		if arg[0] == '-'.runes()[0] {
			if arg[1] == '-'.runes()[0] {
				key := arg[2..]
				// long tag
				fields_filtered := fields.filter(|x| x.long! == key)
				if fields_filtered.len == 0 {
					panic("Invalid argument ${arg}")
				}
				field = fields_filtered[0]
			} else {
				// short tag
				key := arg[1..]
				fields_filtered := fields.filter(|x| x.short! == key)
				if fields_filtered.len == 0 {
					panic("Invalid argument ${arg}")
				}
				field = fields_filtered[0]
			}
		} else {
			// positional arg
			if arg_index < positional_fields.len {
				field = positional_fields[arg_index]
				arg_index++
			} else {
				panic("Too many positional arguments")
			}
		}

		mut split_arg := arg.split("=")
		mut value := ""
		println('split_arg.len ${split_arg.len}')
		if split_arg.len > 1 {
			print("split_arg: ${split_arg}")
			value = split_arg[1..].join("=")
		} else if i < raw_args.len - 1 {
			print("split_arg: ${split_arg}")
			value = raw_args[i + 1]
			if field.typ == 19 { // is bool
				if '${value:s}' in ['true', 'false'] {
					i++
				} else {
					value = 'true'
				}
			} else {
				i++
			}
		}
		if field.is_array {
			if field.name in values {
				mut arr := (values[field.name] or { panic("Can't cast ${field.name} to array") }) as []Any
				arr << parse_to_typ(field.typ, arg, false)
			} else {
				values[field.name] = parse_to_typ(field.typ, arg, true)
			}
		} else {
			values[field.name] = parse_to_typ(field.typ, arg, false)
		}
		i++
	}
	
	return values
}

pub fn parse_to_typ(typ int, value string, is_array bool) Any {
	if is_array {
		value.split(",").map(|x| parse_to_typ(typ, x, false))
	}
	if typ == 21 || typ == 36 {
		return value
	} else if typ == 8 || typ == 84 {
		return strconv.atoi(value) or {
			panic("Can't parse ${value} to int")
		}
	} else if typ == 17 || typ == 96 {
		return strconv.atof64(value) or {
			panic("Can't parse ${value} to f64")
		}
	} else if typ == 19 || typ == 95 {
		return value == "true"
	} else {
		panic("Invalid type of ${value} (${typ})")
	}
}
