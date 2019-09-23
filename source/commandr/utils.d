module commandr.utils;

import commandr;
import std.algorithm : find;
import std.typecons : Tuple, Nullable;


// helpers

private Nullable!T wrapIntoNullable(T)(T[] data) {
    Nullable!T result;
    if (data.length > 0) {
        result = data[0];
    }
    return result;
}

unittest {
    assert(wrapIntoNullable(cast(string[])[]).isNull);

    auto wrapped = wrapIntoNullable(["test"]);
    assert(!wrapped.isNull);
    assert(wrapped.get() == "test");

    wrapped = wrapIntoNullable(["test", "bar"]);
    assert(!wrapped.isNull);
    assert(wrapped.get() == "test");
}

Nullable!Argument getArgumentByName(T)(T aggregate, string name) nothrow pure {
    return aggregate.arguments.find!(o => o.name == name).wrapIntoNullable;
}

Nullable!Option getOptionByName(T)(T aggregate, string name) nothrow pure {
    return aggregate.options.find!(o => o.name == name).wrapIntoNullable;
}

Nullable!Flag getFlagByName(T)(T aggregate, string name) nothrow pure {
    return aggregate.flags.find!(o => o.name == name).wrapIntoNullable;
}

Nullable!Option getOptionByFull(T)(T aggregate, string name) nothrow pure {
    return aggregate.options.find!(o => o.full == name).wrapIntoNullable;
}

Nullable!Flag getFlagByFull(T)(T aggregate, string name) nothrow pure {
    return aggregate.flags.find!(o => o.full == name).wrapIntoNullable;
}

Nullable!Option getOptionByShort(T)(T aggregate, string name) nothrow pure {
    return aggregate.options.find!(o => o.abbrev == name).wrapIntoNullable;
}

Nullable!Flag getFlagByShort(T)(T aggregate, string name) nothrow pure {
    return aggregate.flags.find!(o => o.abbrev == name).wrapIntoNullable;
}

class InvalidProgramException: Exception {
    public this(string msg) {
        super(msg);
    }
}