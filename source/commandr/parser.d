module commandr.parser;

import commandr.program;
import commandr.option;
import commandr.args;
import commandr.help;
import commandr.utils;

import std.algorithm : canFind, count, each;
import std.stdio : writeln, writefln;
import std.string : startsWith, indexOf, format;
import std.range : iota, empty;
import std.typecons : Tuple;


class InvalidArgumentsException: Exception {
    this(string msg) {
        super(msg);
    }
}


/// internal type for holding name-value pair
private alias RawOption = Tuple!(string, "name", string, "value");


/**
 * Splits --option=value into a pair of strings on match, otherwise
 * returns a tuple with option name and null.
 */
private RawOption parseRawOption(string argument) {
    RawOption result;
    
    auto index = argument.indexOf("=");
    if (index > 0) {
        result.name = argument[0..index];
        result.value = argument[index+1..$];        
    }
    else {
        result.name = argument;
        result.value = null;
    }

    return result;
}

/**
 * Parses args.
 */
ProgramArgs parse(T)(T program, ref string[] args) {
    return program.parse(args, new ProgramArgs());
}

private ProgramArgs parse(T)(T program, ref string[] args, ProgramArgs init) {
    ProgramArgs result = init;
    result.name = program.name;

    size_t argIndex = 0;
    int i;
    for (i = 1; i < args.length; ++i) {
        string arg = args[i];
        bool hasNext = i + 1 < args.length;

        // end of args
        if (arg == "--") {
            break;
        }
        // option/flag
        else if (arg.startsWith("-")) {
            bool isLong = arg.startsWith("--");            
            auto raw = parseRawOption(arg[1 + isLong..$]);

            // try matching flag, then fallback to option
            auto flag = isLong ? program.getFlagByFull(raw.name) : program.getFlagByShort(raw.name);
            int flagValue = 1;

            // repeating (-vvvv)
            if (!isLong && flag.isNull && raw.name.length > 1) {
                char letter = raw.name[0];
                // all same character
                if (!raw.name.canFind!(l => l != letter)) {
                    flagValue = cast(int)raw.name.length;
                    raw.name = raw.name[0..1];
                    flag = program.getFlagByShort(raw.name);
                }
            }

            // flag exists, has value
            if (!flag.isNull && raw.value != null) {
                throw new InvalidArgumentsException("-%s is a flag, and cannot accept value".format(raw.name));
            }
            // just exists
            else if (!flag.isNull) {
                auto flagName = flag.get().name;
                result._flags.setOrIncrease(flagName, flagValue);

                if (result._flags[flagName] > 1 && !flag.get().isRepeating) {
                    throw new InvalidArgumentsException("flag -%s cannot be repeated".format(raw.name));
                }

                // dispatch triggers n-times
                iota(flagValue).each!(_ => flag.get().dispatchTriggers());
                continue;
            }

            // trying to match option
            auto option = isLong ? program.getOptionByFull(raw.name) : program.getOptionByShort(raw.name);
            if (option.isNull) {
                throw new InvalidArgumentsException("unknown flag/option %s".format(arg));
            }

            // no value
            if (raw.value is null) {
                if (!hasNext) {
                    throw new InvalidArgumentsException("option %s is missing value".format(raw.name));
                }
                auto next = args[++i];
                if (next.startsWith("-")) {
                    throw new InvalidArgumentsException("option %s is missing value (if value starts with \'-\' character, prefix it with '\\')".format(raw.name));
                }
                raw.value = next;
            }
            result._options.setOrAppend(option.get().name, raw.value);
            option.get().dispatchTriggers(raw.value);
        }
        // argument
        else {
            if (argIndex >= program.arguments.length) {
                break;
            }

            Argument argument = program.arguments[argIndex];
            if (!argument.isRepeating) {
                argIndex += 1;
            }
            result._args.setOrAppend(argument.name, arg);
            argument.dispatchTriggers(arg);
        }
    }

    // shift arguments
    args = args[i..$];

    // fill defaults (before required)
    foreach(option; program.options) {
        if (result.option(option.name) is null && option.defaultValue) {
            result._options[option.name] = [option.defaultValue];
        }
    }

    foreach(arg; program.arguments) {
        if (result.arg(arg.name) is null && arg.defaultValue) {
            result._args[arg.name] = [arg.defaultValue];
        }
    }

    if (result.flag("help")) {
        program.printHelp();
        import core.stdc.stdlib;
        exit(0);
    }

    // check required opts & illegal repetitions
    foreach(option; program.options) {
        if (option.isRequired && result.option(option.name) is null) {
            throw new InvalidArgumentsException("missing required option %s".format(option.name));
        }

        if (!option.isRepeating && result.options(option.name, []).length > 1) {
            throw new InvalidArgumentsException("expected only one value for option %s".format(option.name));
        }
    }
    
    // check required args & illegal repetitions
    foreach(arg; program.arguments) {
        if (arg.isRequired && result.arg(arg.name) is null) {
            throw new InvalidArgumentsException("missing required argument %s".format(arg.name));
        }
    }

    if (args.empty) {
        if (!program.commands.empty) {
            throw new InvalidArgumentsException("missing required subcommand");
        }
    }
    else {
        if (program.commands.empty) {
            throw new InvalidArgumentsException("unknown (excessive) parameter %s".format(args[0]));
        }
        else {
            if ((args[0] in program.commands) is null) {
                throw new InvalidArgumentsException("invalid command %s".format(args[0]));
            }

            result._command = program.commands[args[0]].parse(args, result.copy());
            result._command._parent = result;
        }
    }

    return result;
}

private void setOrAppend(T)(ref T[][string] array, string name, T value) {
    if (name in array) {
        array[name] ~= value;
    } else {
        array[name] = [value];
    }
}
private void setOrAppend(T)(ref T[] array, string name, T value) {
    if (name in array) {
        array[name] ~= value;
    } else {
        array[name] = [value];
    }
}

private void setOrIncrease(ref int[string] array, string name, int value) {
    if (name in array) {
        array[name] += value;
    } else {
        array[name] = value;
    }
}


private auto parseNoRef(Program p, string[] args) {
    return p.parse(args);
}

unittest {
    import std.exception : assertThrown, assertNotThrown;
    
    assertNotThrown!InvalidArgumentsException(
        new Program("test").parseNoRef(["test"])
    );   
}

// flags
unittest {
    import std.exception : assertThrown, assertNotThrown;

    ProgramArgs a;

    a = new Program("test")
            .add(new Flag("t", "test", ""))
            .parseNoRef(["test"]);
    assert(!a.flag("test"));
    assert(a.option("test") is null);
    assert(a.occurencesOf("test") == 0);
    
    a = new Program("test")
            .add(new Flag("t", "test", ""))
            .parseNoRef(["test", "-t"]);
    assert(a.flag("test"));
    assert(a.option("test") is null);
    assert(a.occurencesOf("test") == 1);
    
    a = new Program("test")
            .add(new Flag("t", "test", ""))
            .parseNoRef(["test", "--test"]);
    assert(a.flag("test"));
    assert(a.occurencesOf("test") == 1);
    
    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Flag("t", "test", "")) // no repeating
            .parseNoRef(["test", "--test", "-t"])
    );
    
    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Flag("t", "test", "")) // no repeating
            .parseNoRef(["test", "-tt"])
    );

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Flag("t", "test", "")) // no repeating
            .parseNoRef(["test", "--tt"])
    );
}

// options
unittest {
    import std.exception : assertThrown, assertNotThrown;
    import std.range : empty;

    ProgramArgs a;

    a = new Program("test")
            .add(new Option("t", "test", ""))
            .parseNoRef(["test"]);
    assert(a.option("test") is null);
    assert(a.occurencesOf("test") == 0);
    
    a = new Program("test")
            .add(new Option("t", "test", ""))
            .parseNoRef(["test", "-t", "5"]);
    assert(a.option("test") == "5");
    assert(a.occurencesOf("test") == 0);
    
    a = new Program("test")
            .add(new Option("t", "test", ""))
            .parseNoRef(["test", "-t=5"]);
    assert(a.option("test") == "5");
    assert(a.occurencesOf("test") == 0);
    
    a = new Program("test")
            .add(new Option("t", "test", ""))
            .parseNoRef(["test", "--test", "bar"]);
    assert(a.option("test") == "bar");
    assert(a.occurencesOf("test") == 0);
    
    a = new Program("test")
            .add(new Option("t", "test", ""))
            .parseNoRef(["test", "--test=bar"]);
    assert(a.option("test") == "bar");
    assert(a.occurencesOf("test") == 0);
    
    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Option("t", "test", ""))
            .parseNoRef(["test", "--test=a", "-t", "k"])
    );
    
    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Option("t", "test", "")) // no repeating
            .parseNoRef(["test", "--test", "-t"])
    );
    
    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Option("t", "test", "")) // no value
            .parseNoRef(["test", "--test"])
    );
}

// arguments
unittest {
    import std.exception : assertThrown, assertNotThrown;
    import std.range : empty;

    ProgramArgs a;

    a = new Program("test")
            .add(new Argument("test", ""))
            .parseNoRef(["test"]);
    assert(a.occurencesOf("test") == 0);
    
    a = new Program("test")
            .add(new Argument("test", ""))
            .parseNoRef(["test", "t"]);
    assert(a.occurencesOf("test") == 0);
    assert(a.arg("test") == "t");

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .parseNoRef(["test", "test", "t"])
    );
    
    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Argument("test", "")) // no value
            .parseNoRef(["test", "test", "test"])
    );
}

// required
unittest {
    import std.exception : assertThrown, assertNotThrown;
    
    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Option("t", "test", "").required)
            .parseNoRef(["test"])
    );
    
    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Option("t", "test", ""))
            .add(new Argument("path", "").required)
            .parseNoRef(["test", "--test", "bar"])
    );
    
    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Argument("test", "").required) // no value
            .parseNoRef(["test"])
    );
}

// repating
unittest {
    ProgramArgs a;
    
    a = new Program("test")
            .add(new Flag("t", "test", "").repeating)
            .parseNoRef(["test", "--test", "-t"]);
    assert(a.flag("test"));
    assert(a.occurencesOf("test") == 2);
    
    a = new Program("test")
            .add(new Option("t", "test", "").repeating)
            .parseNoRef(["test", "--test=a", "-t", "k"]);
    assert(a.option("test") == "a");
    assert(a.optionAll("test") == ["a", "k"]);
    assert(a.occurencesOf("test") == 0);
}

// triggers
unittest {
    {
        int counter = 0;
    
        new Program("test")
            .add(new Flag("t", "test", "")
                .repeating
                .trigger({
                    counter += 1;
                }))
            .parseNoRef(["test", "--test", "-t"]);
        assert(counter == 2);
    }

    {
        int counter = 0;
    
        new Program("test")
            .add(new Flag("t", "test", "")
                .repeating
                .trigger({
                    counter += 1;
                }))
            .parseNoRef(["test", "-tt"]);
        assert(counter == 2);
    }

    {
        string[] res;
    
        new Program("test")
            .add(new Option("t", "test", "")
                .repeating
                .trigger((entry) { res ~= entry;}))
            .parseNoRef(["test", "-t=bar", "-t", "kappa"]);
        assert(res == ["bar", "kappa"]);
    }

    {
        string[] res;
    
        new Program("test")
            .add(new Argument("test", "")
                .repeating
                .trigger((entry) { res ~= entry;}))
            .parseNoRef(["test", "bar", "kappa"]);
        assert(res == ["bar", "kappa"]);
    }
}

// default value
unittest {
    ProgramArgs a;

    a = new Program("test")
            .add(new Option("t", "test", "")
                .defaultValue("reee"))
            .parseNoRef(["test"]);
    assert(a.option("test") == "reee");

    a = new Program("test")
            .add(new Option("t", "test", "")
                .defaultValue("reee"))
            .parseNoRef(["test", "--test", "aaa"]);
    assert(a.option("test") == "aaa");

    a = new Program("test")
            .add(new Argument("test", "")
                .defaultValue("reee"))
            .parseNoRef(["test"]);
    assert(a.arg("test") == "reee");

    a = new Program("test")
            .add(new Argument("test", "")
                .defaultValue("reee"))
            .parseNoRef(["test", "bar"]);
    assert(a.args("test") == ["bar"]);
}