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

Nullable!Argument getArgumentByName(Program program, string name) nothrow pure {
    return program.arguments.find!(o => o.name == name).wrapIntoNullable;
}

Nullable!Option getOptionByName(Program program, string name) nothrow pure {
    return program.options.find!(o => o.name == name).wrapIntoNullable;
}

Nullable!Flag getFlagByName(Program program, string name) nothrow pure {
    return program.flags.find!(o => o.name == name).wrapIntoNullable;
}

Nullable!Option getOptionByFull(Program program, string name) nothrow pure {
    return program.options.find!(o => o.full == name).wrapIntoNullable;
}

Nullable!Flag getFlagByFull(Program program, string name) nothrow pure {
    return program.flags.find!(o => o.full == name).wrapIntoNullable;
}

Nullable!Option getOptionByShort(Program program, string name) nothrow pure {
    return program.options.find!(o => o.abbrev == name).wrapIntoNullable;
}

Nullable!Flag getFlagByShort(Program program, string name) nothrow pure {
    return program.flags.find!(o => o.abbrev == name).wrapIntoNullable;
}

class InvalidProgramException: Exception {
    public this(string msg) {
        super(msg);
    }
}