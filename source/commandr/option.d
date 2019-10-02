/**
 * Program and command entries.
 *
 * This module contains interfaces and implementations of various entries.
 * Generally, most APIs expose builder-like pattern, where setters return
 * class instance to allow chaining.
 *
 * Entries are all things that can be added to program or command - that is
 * flags, options and arguments. All entries contain a name - which is an unique
 * identifier for every entry. Names must be a valid alpha numeric identifier.
 *
 * Result of parsing arguments (instance of `ProgramArgs`) allows reading
 * argument values by entry `name` (not by `-short` or `--long-forms`).
 *
 * See_Also:
 *  Flag, Option, Argument
 */
module commandr.option;

import commandr.validators;
import commandr.program : InvalidProgramException;


/**
 * Interface for all program or command entries - flags, options and arguments.
 */
interface IEntry {
    /**
     * Sets entry name.
     */
    public typeof(this) name(string name) pure @safe;

    /**
     * Entry name.
     */
    public string name() const pure nothrow @safe;

    /**
     * Display name for entry.
     *
     * For arguments, this is argument tag value.
     * For options and flags, this is either abbrevation with single dash prefix
     * or full name with double dash prefix.
     */
    public string displayName() const pure nothrow @safe;

    /**
     * Sets entry help description (one-liner).
     */
    public typeof(this) description(string description) pure @safe;

    /**
     * Entry help description (one-liner).
     */
    public string description() const pure nothrow @safe @nogc;

    /**
     * Sets whenever entry can be repeated.
     */
    public typeof(this) repeating(bool repeating = true) pure @safe;

    /**
     * Gets whenever entry can be repeated.
     */
    public bool isRepeating() const pure nothrow @safe @nogc;

    /**
     * Sets entry required flag.
     */
    public typeof(this) required(bool required = true) pure @safe;

    /**
     * Sets entry optional flag.
     */
    public typeof(this) optional(bool optional = true) pure @safe;

    /**
     * Whenever entry is required.
     */
    public bool isRequired() const pure nothrow @safe @nogc;

    /**
     * Sets entry default value.
     */
    public typeof(this) defaultValue(string defaultValue) pure @safe;

    /**
     * Sets entry default value array.
     */
    public typeof(this) defaultValue(string[] defaultValue) pure @safe;

    /**
     * Entry default value array.
     */
    public string[] defaultValue() pure nothrow @safe @nogc;

    /**
     * Adds entry validator.
     */
    public typeof(this) validate(IValidator validator) pure @safe;

    /**
     * Entry validators.
     */
    public IValidator[] validators() pure nothrow @safe @nogc;
}

mixin template EntryImpl() {
    private string _name;
    private string _description;
    private bool _repeating = false;
    private bool _required = false;
    private string[] _default;
    private IValidator[] _validators;

    ///
    public typeof(this) name(string name) pure nothrow @safe @nogc {
        this._name = name;
        return this;
    }

    ///
    public string name() const pure nothrow @safe @nogc {
        return this._name;
    }

    ///
    public typeof(this) description(string description) pure nothrow @safe @nogc {
        this._description = description;
        return this;
    }

    ///
    public string description() const pure nothrow @safe @nogc {
        return this._description;
    }

    ///
    public typeof(this) repeating(bool repeating = true) pure nothrow @safe @nogc {
        this._repeating = repeating;
        return this;
    }

    ///
    public bool isRepeating() const pure nothrow @safe @nogc {
        return this._repeating;
    }

    ///
    public typeof(this) required(bool required = true) pure @safe {
        this._required = required;

        return this;
    }

    ///
    public typeof(this) optional(bool optional = true) pure @safe {
        this.required(!optional);
        return this;
    }

    ///
    public bool isRequired() const pure nothrow @safe @nogc {
        return this._required;
    }

    ///
    public typeof(this) defaultValue(string defaultValue) pure @safe {
        return this.defaultValue([defaultValue]);
    }

    ///
    public typeof(this) defaultValue(string[] defaultValue) pure @safe {
        this._default = defaultValue;
        this._required = false;
        return this;
    }

    ///
    public string[] defaultValue() pure nothrow @safe @nogc {
        return this._default;
    }

    ///
    public typeof(this) validate(IValidator validator) pure @safe {
        this._validators ~= validator;
        return this;
    }

    ///
    public IValidator[] validators() pure nothrow @safe @nogc {
        return this._validators;
    }
}

/**
 * Option interface.
 *
 * Used by flags and options, which both contain short and long names.
 * Either can be null but not both.
 */
interface IOption: IEntry {
    /**
     * Sets option full name (long-form).
     *
     * Set to null to disable long form.
     */
    public typeof(this) full(string full) pure nothrow @safe @nogc;

    /**
     * Option full name (long-form).
     */
    public string full() const pure nothrow @safe @nogc;

    /// ditto
    public alias long_ = full;

    /**
     * Sets option abbrevation (short-form).
     *
     * Set to null to disable short form.
     */
    public typeof(this) abbrev(string abbrev) pure nothrow @safe @nogc;

    /**
     * Sets option abbrevation (short-form).
     */
    public string abbrev() const pure nothrow @safe @nogc;

    /// ditto
    public alias short_ = abbrev;
}

mixin template OptionImpl() {
    private string _abbrev;
    private string _full;

    ///
    public string displayName() const nothrow pure @safe {
        if (_abbrev) {
            return "-" ~ _abbrev;
        }
        return "--" ~ _full;
    }

    ///
    public typeof(this) full(string full) pure nothrow @safe @nogc {
        this._full = full;
        return this;
    }

    ///
    public string full() const pure nothrow @safe @nogc {
        return this._full;
    }

    ///
    public alias long_ = full;

    ///
    public typeof(this) abbrev(string abbrev) pure nothrow @safe @nogc {
        this._abbrev = abbrev;
        return this;
    }

    ///
    public string abbrev() const pure nothrow @safe @nogc {
        return this._abbrev;
    }

    ///
    public alias short_ = abbrev;
}


/**
 * Represents a flag.
 *
 * Flag hold a single boolean value.
 * Flags are optional and cannot be set as required.
 */
public class Flag: IOption {
    mixin EntryImpl;
    mixin OptionImpl;

    /**
     * Creates new flag.
     *
     * Full flag name (long-form) is set to name parameter value.
     *
     * Params:
     *   name - flag unique name.
     */
    public this(string name) pure nothrow @safe @nogc {
        this._name = name;
        this._full = name;
    }


    /**
     * Creates new flag.
     *
     * Name defaults to long form value.
     *
     * Params:
     *   abbrev - Flag short name (null for none)
     *   full - Flag full name (null for none)
     *   description - Flag help description
     */
    public this(string abbrev, string full, string description) pure nothrow @safe @nogc {
        this._name = full;
        this._full = full;
        this._abbrev = abbrev;
        this._description = description;
    }
}

/**
 * Represents an option.
 *
 * Options hold any value as string (or array of strings).
 * Options by default are optional, but can be marked as required.
 *
 * Order in which options are passed does not matter.
 */
public class Option: IOption {
    mixin OptionImpl;
    mixin EntryImpl;

    private string _tag = "value";


    /**
     * Creates new option.
     *
     * Full option name (long-form) is set to `name` parameter value.
     *
     * Params:
     *   name - option unique name.
     */
    public this(string name) pure nothrow @safe @nogc {
        this._name = name;
        this._full = name;
    }

    /**
     * Creates new option.
     *
     * Name defaults to long form value.
     *
     * Params:
     *   abbrev - Option short name (null for none)
     *   full - Option full name (null for none)
     *   description - Option help description
     */
    public this(string abbrev, string full, string description) pure nothrow @safe @nogc {
        this._name = full;
        this._full = full;
        this._abbrev = abbrev;
        this._description = description;
    }

    /**
     * Sets option value tag.
     *
     * A tag is a token displayed in place of option value.
     * Default tag is `value`.
     *
     * For example, for a option that takes path to configuration file,
     * one can create `--config` option and set `tag` to `config-path`, so that in
     * help it is displayed as `--config=config-path` instead of `--config=value`
     */
    public typeof(this) tag(string tag) pure nothrow @safe @nogc {
        this._tag = tag;
        return this;
    }

    /**
     * Option value tag.
     */
    public string tag() const pure nothrow @safe @nogc {
        return this._tag;
    }
}

/**
 * Represents an argument.
 *
 * Arguments are positional parameters passed to program and are required by default.
 * Only last argument can be repeating or optional.
 */
public class Argument: IEntry {
    mixin EntryImpl;

    private string _tag;

    /**
     * Creates new argument.
     *
     * Params:
     *  name - Argument name
     *  description - Help description
     */
    public this(string name, string description = null) nothrow pure @safe @nogc {
        this._name = name;
        this._description = description;
        this._required = true;
        this._tag = name;
    }

    /**
     * Gets argument display name (tag or name).
     */
    public string displayName() const nothrow pure @safe {
        return this._tag;
    }

    /**
     * Sets argument tag.
     *
     * A tag is a token displayed in place of argument.
     * By default it is name of the argument.
     */
    public typeof(this) tag(string tag) pure nothrow @safe @nogc {
        this._tag = tag;
        return this;
    }

    /**
     * Argument tag
     */
    public string tag() const pure nothrow @safe @nogc {
        return this._tag;
    }
}

/**
 * Thrown when user-passed data is invalid.
 *
 * This exception is thrown during parsing phase when user passed arguments (e.g. invalid option, invalid value).
 *
 * This exception is automatically caught if using `parse` function.
 */
public class InvalidArgumentsException: Exception {
    /**
     * Creates new InvalidArgumentException
     */
    public this(string msg) nothrow pure @safe @nogc {
        super(msg);
    }
}

// options
unittest {
    assert(!new Option("t", "test", "").isRequired);
}

// arguments
unittest {
    assert(new Argument("test", "").isRequired);
}
