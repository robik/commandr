module commandr.option;

import commandr.validators;
import commandr.program : InvalidProgramException;


interface IEntry {
    public typeof(this) name(string name) pure @safe;
    public string name() const pure nothrow @safe;

    public string displayName() const pure nothrow @safe;

    public typeof(this) description(string description) pure @safe;
    public string description() const pure nothrow @safe @nogc;

    public typeof(this) repeating(bool repeating = true) pure @safe;
    public bool isRepeating() const pure nothrow @safe @nogc;

    public typeof(this) required(bool required = true) pure @safe;
    public typeof(this) optional(bool optional = true) pure @safe;
    public bool isRequired() const pure nothrow @safe @nogc;

    public typeof(this) defaultValue(string defaultValue) pure @safe;
    public string defaultValue() const pure nothrow @safe @nogc;

    public typeof(this) validate(IValidator validator) pure @safe;
    public IValidator[] validators() pure nothrow @safe @nogc;
}

mixin template EntryImpl() {
    private string _name;
    private string _description;
    private bool _repeating = false;
    private bool _required = false;
    private string _default;
    private IValidator[] _validators;


    public typeof(this) name(string name) pure nothrow @safe @nogc {
        this._name = name;
        return this;
    }

    public string name() const pure nothrow @safe @nogc {
        return this._name;
    }

    public typeof(this) description(string description) pure nothrow @safe @nogc {
        this._description = description;
        return this;
    }

    public string description() const pure nothrow @safe @nogc {
        return this._description;
    }

    public typeof(this) repeating(bool repeating = true) pure nothrow @safe @nogc {
        this._repeating = repeating;
        return this;
    }

    public bool isRepeating() const pure nothrow @safe @nogc {
        return this._repeating;
    }

    public typeof(this) required(bool required = true) pure @safe {
        this._required = required;

        return this;
    }

    public typeof(this) optional(bool optional = true) pure @safe {
        this.required(!optional);
        return this;
    }

    public bool isRequired() const pure nothrow @safe @nogc {
        return this._required;
    }

    public typeof(this) defaultValue(string defaultValue) pure @safe {
        this._default = defaultValue;
        this._required = false;
        return this;
    }

    public string defaultValue() const pure nothrow @safe @nogc {
        return this._default;
    }

    public typeof(this) validate(IValidator validator) pure @safe {
        this._validators ~= validator;
        return this;
    }

    public IValidator[] validators() pure nothrow @safe @nogc {
        return this._validators;
    }
}

interface IOption: IEntry {
    public typeof(this) full(string full) pure nothrow @safe @nogc;
    public string full() const pure nothrow @safe @nogc;

    public typeof(this) abbrev(string abbrev) pure nothrow @safe @nogc;
    public string abbrev() const pure nothrow @safe @nogc;

    public alias long_ = full;
    public alias short_ = abbrev;
}

mixin template OptionImpl() {
    private string _abbrev;
    private string _full;

    public string displayName() const nothrow pure @safe {
        if (_abbrev) {
            return "-" ~ _abbrev;
        }
        return "--" ~ _full;
    }

    public typeof(this) full(string full) pure nothrow @safe @nogc {
        this._full = full;
        return this;
    }

    public string full() const pure nothrow @safe @nogc {
        return this._full;
    }

    public typeof(this) abbrev(string abbrev) pure nothrow @safe @nogc {
        this._abbrev = abbrev;
        return this;
    }

    public string abbrev() const pure nothrow @safe @nogc {
        return this._abbrev;
    }

    public alias long_ = full;
    public alias short_ = abbrev;
}


class Flag: IOption {
    mixin EntryImpl;
    mixin OptionImpl;

    public this(string name) pure nothrow @safe @nogc {
        this._name = name;
        this._full = name;
    }

    public this(string abbrev, string full, string description) pure nothrow @safe @nogc {
        this._name = full;
        this._full = full;
        this._abbrev = abbrev;
        this._description = description;
    }
}

class Option: IOption {
    mixin OptionImpl;
    mixin EntryImpl;

    private string _tag = "value";

    public this(string name) pure nothrow @safe @nogc {
        this._name = name;
        this._full = name;
    }

    public this(string abbrev, string full, string description) pure nothrow @safe @nogc {
        this._name = full;
        this._full = full;
        this._abbrev = abbrev;
        this._description = description;
    }

    public typeof(this) tag(string description) pure nothrow @safe @nogc {
        this._description = description;
        return this;
    }

    public string tag() const pure nothrow @safe @nogc {
        return this._tag;
    }
}

class Argument: IEntry {
    mixin EntryImpl;

    private string _tag;

    this(string name, string description = null) nothrow pure @safe @nogc {
        this._name = name;
        this._description = description;
        this._required = true;
        this._tag = name;
    }

    public string displayName() const nothrow pure @safe {
        return this._tag;
    }

    public typeof(this) tag(string description) pure nothrow @safe @nogc {
        this._description = description;
        return this;
    }

    public string tag() const pure nothrow @safe @nogc {
        return this._tag;
    }
}

class InvalidArgumentsException: Exception {
    this(string msg) nothrow pure @safe @nogc {
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
