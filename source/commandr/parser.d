/**
 * Argument parsing functionality.
 *
 * See_Also:
 *  parse, parseArgs
 */
module commandr.parser;

import commandr.program;
import commandr.option;
import commandr.args;
import commandr.help;
import commandr.utils;

import std.algorithm : canFind, count, each;
import std.stdio : writeln, writefln, stderr;
import std.string : startsWith, indexOf, format;
import std.range : empty;
import std.typecons : Tuple;
private import core.stdc.stdlib;


/**
 * Parses program arguments.
 *
 * Returns instance of `ProgramArgs`, which allows working on parsed data.
 *
 * On top of parsing arguments, this function catches `InvalidArgumentsException`,
 * handles `--version` and `--help` flags as well as `help` subcommand.
 * Exception is handled by printing out the error message along with program usage information
 * and exiting.
 *
 * Version and help is handled by prining out information and exiting.
 *
 * If you want to only parse argument without additional handling, see `parseArgs`.
 *
 * Similarly to `parseArgs`, `args` array is taken by reference, after call it points to first
 * not-parsed argument (after `--`).
 *
 * See_Also:
 *   `parseArgs`
 */
public ProgramArgs parse(Program program, ref string[] args, HelpOutput helpConfig = HelpOutput.init) {
    try {
        return parseArgs(program, args, helpConfig);
    } catch(InvalidArgumentsException e) {
        stderr.writeln("Error: ", e.msg);
        program.printUsage(helpConfig);
        exit(0);
        assert(0);
    }
}


/**
 * Parses args.
 *
 * Returns instance of `ProgramArgs`, which allows working on parsed data.
 *
 * Program model by default adds version flag and help flags and subcommand which need to be
 * handled by the caller. If you want to have the default behavior, use `parse` which handles
 * above flags.
 *
 * `args` array is taken by reference, after call it points to first not-parsed argument (after `--`).
 *
 * Throws:
 *   InvalidArgumentException
 *
 * See_Also:
 *   `parse`
 */
public ProgramArgs parseArgs(Program program, ref string[] args, HelpOutput helpConfig = HelpOutput.init) {
    args = args[1..$];
    return program.parseArgs(args, new ProgramArgs(), helpConfig);
}

private ProgramArgs parseArgs(
    Command program,
    ref string[] args,
    ProgramArgs init,
    HelpOutput helpConfig = HelpOutput.init
) {
    // TODO: Split
    ProgramArgs result = init;
    result.name = program.name;
    size_t argIndex = 0;

    while (args.length) {
        string arg = args[0];
        args = args[1..$];
        immutable bool hasNext = args.length > 0;

        // end of args
        if (arg == "--") {
            break;
        }
        // option/flag
        else if (arg.startsWith("-")) {
            immutable bool isLong = arg.startsWith("--");
            auto raw = parseRawOption(arg[1 + isLong..$]);

            // try matching flag, then fallback to option
            auto flag = isLong ? program.getFlagByFull(raw.name, true) : program.getFlagByShort(raw.name, true);
            int flagValue = 1;

            // repeating (-vvvv)
            if (!isLong && flag.isNull && raw.name.length > 1) {
                char letter = raw.name[0];
                // all same character
                if (!raw.name.canFind!(l => l != letter)) {
                    flagValue = cast(int)raw.name.length;
                    raw.name = raw.name[0..1];
                    flag = program.getFlagByShort(raw.name, true);
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

                continue;
            }

            // trying to match option
            auto option = isLong ? program.getOptionByFull(raw.name, true) : program.getOptionByShort(raw.name, true);
            if (option.isNull) {
                string suggestion = (isLong ? program.fullNames : program.abbrevations).matchingCandidate(raw.name);

                if (suggestion) {
                    throw new InvalidArgumentsException(
                        "unknown flag/option %s, did you mean %s%s?".format(arg, isLong ? "--" : "-", suggestion)
                    );
                }
                else {
                    throw new InvalidArgumentsException("unknown flag/option %s".format(arg));
                }
            }

            // no value
            if (raw.value is null) {
                if (!hasNext) {
                    throw new InvalidArgumentsException(
                        "option %s%s is missing value".format(isLong ? "--" : "-", raw.name)
                    );
                }
                auto next = args[0];
                args = args[1..$];
                if (next.startsWith("-")) {
                    throw new InvalidArgumentsException(
                        "option %s%s is missing value (if value starts with \'-\' character, prefix it with '\\')"
                        .format(isLong ? "--" : "-", raw.name)
                    );
                }
                raw.value = next;
            }
            result._options.setOrAppend(option.get().name, raw.value);
        }
        // argument
        else if (argIndex < program.arguments.length) {
            Argument argument = program.arguments[argIndex];
            if (!argument.isRepeating) {
                argIndex += 1;
            }
            result._args.setOrAppend(argument.name, arg);
        }
        // command
        else {
            if (program.commands.length == 0) {
                throw new InvalidArgumentsException("unknown (excessive) parameter %s".format(arg));
            }
            else if ((arg in program.commands) is null) {
                string suggestion = program.commands.keys.matchingCandidate(arg);
                throw new InvalidArgumentsException("unknown command %s, did you mean %s?".format(arg, suggestion));
            }
            else {
                result._command = program.commands[arg].parseArgs(args, result.copy());
                result._command._parent = result;
                break;
            }
        }
    }

    if (args.length > 0)
        result._args_rest = args.dup;

    if (result.flag("help")) {
        program.printHelp(helpConfig);
        exit(0);
    }

    if (result.flag("version")) {
        writeln(program.version_);
        exit(0);
    }

    // fill defaults (before required)
    foreach(option; program.options) {
        if (result.option(option.name) is null && option.defaultValue) {
            result._options[option.name] = option.defaultValue;
        }
    }

    foreach(arg; program.arguments) {
        if (result.arg(arg.name) is null && arg.defaultValue) {
            result._args[arg.name] = arg.defaultValue;
        }
    }

    // post-process options: check required opts, illegal repetitions and validate
    foreach (option; program.options) {
        if (option.isRequired && result.option(option.name) is null) {
            throw new InvalidArgumentsException("missing required option %s".format(option.name));
        }

        if (!option.isRepeating && result.options(option.name, []).length > 1) {
            throw new InvalidArgumentsException("expected only one value for option %s".format(option.name));
        }

        if (option.validators.empty) {
            continue;
        }

        auto values = result.options(option.name);
        foreach (validator; option.validators)  {
            validator.validate(option, values);
        }
    }

    // check required args & illegal repetitions
    foreach (arg; program.arguments) {
        if (arg.isRequired && result.arg(arg.name) is null) {
            throw new InvalidArgumentsException("missing required argument %s".format(arg.name));
        }

        if (arg.validators.empty) {
            continue;
        }

        auto values = result.args(arg.name);
        foreach (validator; arg.validators)  {
            validator.validate(arg, values);
        }
    }

    if (result.command is null && program.commands.length > 0) {
        if (program.defaultCommand !is null) {
            result._command = program.commands[program.defaultCommand].parseArgs(args, result.copy());
            result._command._parent = result;
        }
        else {
            throw new InvalidArgumentsException("missing required subcommand");
        }
    }

    return result;
}

package ProgramArgs parseArgsNoRef(Program p, string[] args) {
    return p.parseArgs(args);
}

// internal type for holding name-value pair
private alias RawOption = Tuple!(string, "name", string, "value");


/*
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

private void setOrAppend(T)(ref T[][string] array, string name, T value) {
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

unittest {
    import std.exception : assertThrown, assertNotThrown;

    assertNotThrown!InvalidArgumentsException(
        new Program("test").parseArgsNoRef(["test"])
    );
}

// flags
unittest {
    import std.exception : assertThrown, assertNotThrown;

    ProgramArgs a;

    a = new Program("test")
            .add(new Flag("t", "test", ""))
            .parseArgsNoRef(["test"]);
    assert(!a.flag("test"));
    assert(a.option("test") is null);
    assert(a.occurencesOf("test") == 0);

    a = new Program("test")
            .add(new Flag("t", "test", ""))
            .parseArgsNoRef(["test", "-t"]);
    assert(a.flag("test"));
    assert(a.option("test") is null);
    assert(a.occurencesOf("test") == 1);

    a = new Program("test")
            .add(new Flag("t", "test", ""))
            .parseArgsNoRef(["test", "--test"]);
    assert(a.flag("test"));
    assert(a.occurencesOf("test") == 1);

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Flag("t", "test", "")) // no repeating
            .parseArgsNoRef(["test", "--test", "-t"])
    );

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Flag("t", "test", "")) // no repeating
            .parseArgsNoRef(["test", "-tt"])
    );

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Flag("t", "test", "")) // no repeating
            .parseArgsNoRef(["test", "--tt"])
    );
}

// options
unittest {
    import std.exception : assertThrown, assertNotThrown;
    import std.range : empty;

    ProgramArgs a;

    a = new Program("test")
            .add(new Option("t", "test", ""))
            .parseArgsNoRef(["test"]);
    assert(a.option("test") is null);
    assert(a.occurencesOf("test") == 0);

    a = new Program("test")
            .add(new Option("t", "test", ""))
            .parseArgsNoRef(["test", "-t", "5"]);
    assert(a.option("test") == "5");
    assert(a.occurencesOf("test") == 0);

    a = new Program("test")
            .add(new Option("t", "test", ""))
            .parseArgsNoRef(["test", "-t=5"]);
    assert(a.option("test") == "5");
    assert(a.occurencesOf("test") == 0);

    a = new Program("test")
            .add(new Option("t", "test", ""))
            .parseArgsNoRef(["test", "--test", "bar"]);
    assert(a.option("test") == "bar");
    assert(a.occurencesOf("test") == 0);

    a = new Program("test")
            .add(new Option("t", "test", ""))
            .parseArgsNoRef(["test", "--test=bar"]);
    assert(a.option("test") == "bar");
    assert(a.occurencesOf("test") == 0);

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Option("t", "test", ""))
            .parseArgsNoRef(["test", "--test=a", "-t", "k"])
    );

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Option("t", "test", "")) // no repeating
            .parseArgsNoRef(["test", "--test", "-t"])
    );

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Option("t", "test", "")) // no value
            .parseArgsNoRef(["test", "--test"])
    );
}

// arguments
unittest {
    import std.exception : assertThrown, assertNotThrown;
    import std.range : empty;

    ProgramArgs a;

    a = new Program("test")
            .add(new Argument("test", "").optional)
            .parseArgsNoRef(["test"]);
    assert(a.occurencesOf("test") == 0);

    a = new Program("test")
            .add(new Argument("test", ""))
            .parseArgsNoRef(["test", "t"]);
    assert(a.occurencesOf("test") == 0);
    assert(a.arg("test") == "t");

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .parseArgsNoRef(["test", "test", "t"])
    );

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Argument("test", "")) // no value
            .parseArgsNoRef(["test", "test", "test"])
    );
}

// required
unittest {
    import std.exception : assertThrown, assertNotThrown;

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Option("t", "test", "").required)
            .parseArgsNoRef(["test"])
    );

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Option("t", "test", ""))
            .add(new Argument("path", "").required)
            .parseArgsNoRef(["test", "--test", "bar"])
    );

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Argument("test", "").required) // no value
            .parseArgsNoRef(["test"])
    );
}

// repating
unittest {
    ProgramArgs a;

    a = new Program("test")
            .add(new Flag("t", "test", "").repeating)
            .parseArgsNoRef(["test", "--test", "-t"]);
    assert(a.flag("test"));
    assert(a.occurencesOf("test") == 2);

    a = new Program("test")
            .add(new Option("t", "test", "").repeating)
            .parseArgsNoRef(["test", "--test=a", "-t", "k"]);
    assert(a.option("test") == "k");
    assert(a.optionAll("test") == ["a", "k"]);
    assert(a.occurencesOf("test") == 0);
}

// default value
unittest {
    ProgramArgs a;

    a = new Program("test")
            .add(new Option("t", "test", "")
                .defaultValue("reee"))
            .parseArgsNoRef(["test"]);
    assert(a.option("test") == "reee");

    a = new Program("test")
            .add(new Option("t", "test", "")
                .defaultValue("reee"))
            .parseArgsNoRef(["test", "--test", "aaa"]);
    assert(a.option("test") == "aaa");

    a = new Program("test")
            .add(new Argument("test", "")
                .optional
                .defaultValue("reee"))
            .parseArgsNoRef(["test"]);
    assert(a.arg("test") == "reee");

    a = new Program("test")
            .add(new Argument("test", "")
                .optional
                .defaultValue("reee"))
            .parseArgsNoRef(["test", "bar"]);
    assert(a.args("test") == ["bar"]);
}

// rest
unittest {
    ProgramArgs a;
    auto args = ["test", "--", "bar"];
    a = new Program("test")
            .add(new Argument("test", "")
                .optional
                .defaultValue("reee"))
            .parseArgs(args);
    assert(a.args("test") == ["reee"]);
    assert(a.argsRest == ["bar"]);
    assert(args == ["bar"]);
}

// subcommands
unittest {
    import std.exception : assertThrown;

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Argument("test", ""))
            .add(new Command("a"))
            .add(new Command("b")
                .add(new Command("c")))
            .parseArgsNoRef(["test", "cccc"])
    );

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Argument("test", ""))
            .add(new Command("a"))
            .add(new Command("b")
                .add(new Command("c")))
            .parseArgsNoRef(["test", "cccc", "a", "c"])
    );

    ProgramArgs a;
    a = new Program("test")
            .add(new Argument("test", ""))
            .add(new Command("a"))
            .add(new Command("b")
                .add(new Command("c")))
            .parseArgsNoRef(["test", "cccc", "b", "c"]);
    assert(a.args("test") == ["cccc"]);
    assert(a.command !is null);
    assert(a.command.name == "b");
    assert(a.command.command !is null);
    assert(a.command.command.name == "c");


    auto args = ["test", "cccc", "a", "--", "c"];
    a = new Program("test")
            .add(new Argument("test", ""))
            .add(new Command("a"))
            .add(new Command("b")
                .add(new Command("c")))
            .parseArgs(args);
    assert(a.args("test") == ["cccc"]);
    assert(a.command !is null);
    assert(a.command.name == "a");
    assert(a.command.argsRest == ["c"]);
    assert(args == ["c"]);

    assertThrown!InvalidArgumentsException(
        new Program("test")
            .add(new Argument("test", ""))
            .add(new Command("a"))
            .add(new Command("b")
                .add(new Command("c")))
            .parseArgsNoRef(["test", "cccc", "b", "--", "c"])
    );
}

// default subcommand
unittest {
    ProgramArgs a;

    a = new Program("test")
            .add(new Command("a"))
            .add(new Command("b")
                .add(new Command("c")))
            .defaultCommand("a")
            .parseArgsNoRef(["test"]);

    assert(a.command !is null);
    assert(a.command.name == "a");


    a = new Program("test")
            .add(new Command("a"))
            .add(new Command("b")
                .add(new Command("c"))
                .defaultCommand("c"))
            .defaultCommand("b")
            .parseArgsNoRef(["test"]);

    assert(a.command !is null);
    assert(a.command.name == "b");
    assert(a.command.command !is null);
    assert(a.command.command.name == "c");
}
