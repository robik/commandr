module commandr.utils;

import commandr;
import std.array : array;
import std.algorithm : find, map, levenshteinDistance;
import std.typecons : Tuple, Nullable;
import std.range : isInputRange, ElementType;


// helpers

private Nullable!T wrapIntoNullable(T)(T[] data) pure nothrow @safe @nogc {
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

Nullable!Option getOptionByFull(T)(T aggregate, string name, bool useDefault = false) nothrow pure @safe {
    auto ret = aggregate.options.find!(o => o.full == name).wrapIntoNullable;
    if (ret.isNull && aggregate.defaultCommand !is null && useDefault)
        ret = aggregate.commands[aggregate.defaultCommand].getOptionByFull(name, useDefault);
    return ret;
}

Nullable!Flag getFlagByFull(T)(T aggregate, string name, bool useDefault = false) nothrow pure @safe {
    auto ret = aggregate.flags.find!(o => o.full == name).wrapIntoNullable;
    if (ret.isNull && aggregate.defaultCommand !is null && useDefault)
        ret = aggregate.commands[aggregate.defaultCommand].getFlagByFull(name, useDefault);
    return ret;
}

Nullable!Option getOptionByShort(T)(T aggregate, string name, bool useDefault = false) nothrow pure @safe {
    auto ret = aggregate.options.find!(o => o.abbrev == name).wrapIntoNullable;
    if (ret.isNull && aggregate.defaultCommand !is null && useDefault)
        ret = aggregate.commands[aggregate.defaultCommand].getOptionByShort(name, useDefault);
    return ret;
}

Nullable!Flag getFlagByShort(T)(T aggregate, string name, bool useDefault = false) nothrow pure @safe {
    auto ret = aggregate.flags.find!(o => o.abbrev == name).wrapIntoNullable;
    if (ret.isNull && aggregate.defaultCommand !is null && useDefault)
        ret = aggregate.commands[aggregate.defaultCommand].getFlagByShort(name, useDefault);
    return ret;
}

string getEntryKindName(IEntry entry) nothrow pure @safe {
    if (cast(Option)entry) {
        return "option";
    }

    else if (cast(Flag)entry) {
        return "flag";
    }

    else if (cast(Argument)entry) {
        return "argument";
    }
    else {
        return null;
    }
}

string matchingCandidate(string[] values, string current) @safe {
    auto distances = values.map!(v => levenshteinDistance(v, current));

    immutable long index = distances.minIndex;
    if (index < 0) {
        return null;
    }

    return values[index];
}

unittest {
    assert (matchingCandidate(["test", "bar"], "tst") == "test");
    assert (matchingCandidate(["test", "bar"], "barr") == "bar");
    assert (matchingCandidate([], "barr") == null);
}


// minIndex is not in GDC (ugh)
ptrdiff_t minIndex(T)(T range) if(isInputRange!T) {
    ptrdiff_t index, minIndex;
    ElementType!T min = ElementType!T.max;

    foreach(el; range) {
        if (el < min) {
            min = el;
            minIndex = index;
        }
        index += 1;
    }

    if (min == ElementType!T.max) {
        return -1;
    }

    return minIndex;
}

unittest {
    assert([1, 0].minIndex == 1);
    assert([0, 1, 2].minIndex == 0);
    assert([2, 1, 2].minIndex == 1);
    assert([2, 1, 0].minIndex == 2);
    assert([1, 1, 0].minIndex == 2);
    assert([0, 1, 0].minIndex == 0);
    assert((cast(int[])[]).minIndex == -1);
}
