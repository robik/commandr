module commandr.option;


mixin template Requireable() {
    private bool _required;

    public typeof(this) required(bool required = true) pure nothrow {
        this._required = required;
        return this;
    }

    public typeof(this) optional(bool optional = true) pure nothrow {
        this._required = !optional;
        return this;
    }

    public bool isRequired() const pure nothrow {
        return this._required;
    }
}

mixin template Triggerable(T...) {
    alias TriggerHandler = void delegate(T);
    private TriggerHandler[] _triggers;

    public typeof(this) trigger(TriggerHandler handler) {
        _triggers ~= handler;
        return this;
    }

    public TriggerHandler[] triggers() {
        return this._triggers;
    }

    public void dispatchTriggers(T data) {
        foreach(trigger; _triggers) {
            trigger(data);
        }
    }
}
mixin template Defaultable(T) {
    private T _default;

    public typeof(this) defaultValue(T defaultValue) pure nothrow {
        this._default = defaultValue;
        return this;
    }

    public T defaultValue() const pure nothrow {
        return this._default;
    }
}

mixin template BaseArgument() {
    private string _name;
    private string _description;
    private bool _repeating;


    public typeof(this) name(string name) pure nothrow {
        this._name = name;
        return this;
    }

    public string name() const pure nothrow {
        return this._name;
    }

    public typeof(this) description(string description) pure nothrow {
        this._description = description;
        return this;
    }

    public string description() const pure nothrow {
        return this._description;
    }

    public typeof(this) repeating(bool repeating = true) pure nothrow {
        this._repeating = repeating;
        return this;
    }

    public bool isRepeating() const pure nothrow {
        return this._repeating;
    }
}


mixin template BaseOption() {
    private string _abbrev;
    private string _full;

    public typeof(this) full(string full) pure nothrow {
        this._full = full;
        return this;
    }

    public string full() const pure nothrow {
        return this._full;
    }

    public typeof(this) abbrev(string abbrev) pure nothrow {
        this._abbrev = abbrev;
        return this;
    }

    public string abbrev() const pure nothrow {
        return this._abbrev;
    }

    public alias long_ = full;
    public alias short_ = abbrev;
}


struct Flag {
    mixin BaseArgument;
    mixin BaseOption;
    mixin Triggerable!();


    public this(string name) pure nothrow {
        this._name = name;
        this._full = name;
    }

    public this(string abbrev, string full, string description) pure nothrow {
        this._name = full;
        this._full = full;
        this._abbrev = abbrev;
        this._description = description;
    }
}

struct Option {
    mixin BaseArgument;
    mixin BaseOption;
    mixin Requireable;
    mixin Triggerable!string;
    mixin Defaultable!string;

    private string _tag = "VALUE";


    public this(string name) pure nothrow {
        this._name = name;
        this._full = name;
    }

    public this(string abbrev, string full, string description) pure nothrow {
        this._name = full;
        this._full = full;
        this._abbrev = abbrev;
        this._description = description;
    }

    public typeof(this) tag(string description) pure nothrow {
        this._description = description;
        return this;
    }

    public string tag() const pure nothrow {
        return this._tag;
    }
}

struct Argument {
    mixin BaseArgument;
    mixin Requireable;
    mixin Triggerable!string;
    mixin Defaultable!string;
}