module commandr.help;

import commandr.program;
import commandr.option;
import std.algorithm : filter, map;
import std.array : join;
import std.stdio : writefln, writeln, write;
import std.string : format;
import std.range : chain, empty, padRight;


struct HelpOutput {
    bool colors;
    // bool compact = false;
    int indent = 20;
}

void printHelp(T)(T program) {
    static if (is(T == Program)) {
        writefln("%s: %s %s(%s)%s", program.name, program.summary, ansi("2"), program.version_, ansi("0"));
        writeln();
    }
    else {
        writefln("%s: %s", program.chain.join(" "), program.summary);
        writeln();
    }

    writefln("%sUSAGE%s", ansi("1"), ansi("0"));
    write("  $ "); // prefix for usage
    program.printUsage();
    writeln();

    if (!program.flags.empty) {
        writefln("%sFLAGS%s", ansi("1"), ansi("0"));
        foreach(flag; program.flags) {
            flag.printHelp();
        }
        writeln();
    }

    if (!program.options.empty) {
        writefln("%sOPTIONS%s", ansi("1"), ansi("0"));
        foreach(option; program.options) {
            option.printHelp();
        }
        writeln();
    }

    if (!program.arguments.empty) {
        writefln("%sARGUMENTS%s", ansi("1"), ansi("0"));
        foreach(arg; program.arguments) {
            arg.printHelp();
        }
        writeln();
    }

    if (!program.commands.empty) {
        writefln("%sSUBCOMMANDS%s", ansi("1"), ansi("0"));
        foreach(key, command; program.commands) {
            writefln("  %-28s%s%s%s", key, ansi("2"), command.summary, ansi("0"));
        }
        writeln();
    }
}

void printUsage(Program program) {
    string optionsUsage = "[options]";
    if (program.options.length + program.flags.length <= 8) {
        optionsUsage = chain(
            program.flags.map!optionUsage,
            program.options.map!optionUsage
        ).join(" ");
    }

    string commands = program.commands.empty ? "" : (
        "<%s>".format(program.commands.length > 6 ? "COMMAND" : program.commands.keys.join("|"))
    );
    string args = program.arguments.map!(argUsage).join(" ");

    writefln("%s %s %s%s",
        program.binaryName,
        optionsUsage,
        args.empty ? "" : args ~ " ",
        commands
    );
}

void printUsage(Command command) {
    string optionsUsage = "[options]";
    if (command.options.length + command.flags.length <= 8) {
        optionsUsage = chain(
            command.flags.map!optionUsage,
            command.options.map!optionUsage
        ).join(" ");
    }

    string commands = command.commands.empty ? "" : (
        "<%s>".format(command.commands.length > 6 ? "COMMAND" : command.commands.keys.join("|"))
    );
    string args = command.arguments.map!(argUsage).join(" ");

    writefln("%s %s %s%s",
        usageChain(command),
        optionsUsage,
        args.empty ? "" : args ~ " ",
        commands
    );
}

private void printHelp(Flag flag) {
    string left = optionNames(flag);
    writefln("  %-26s  %s%s%s", left, ansi("2"), flag.description, ansi("0"));
}

private void printHelp(Option option) {
    string left = optionNames(option);
    size_t length = left.length + option.tag.length + 1;
    string formatted = "%s %s%s%s".format(left, ansi("4"), option.tag, ansi("0"));

    writefln("  %s  %s%s%s", formatted.padRight(' ', 26 + (formatted.length - length)), ansi("2"), option.description, ansi("0"));
}

private void printHelp(Argument arg) {
    writefln("  %-26s  %s%s%s", arg.name, ansi("2"), arg.description, ansi("0"));
}

private string usageChain(Command target) {
    Command[] commands = [];
    Command dest = target.parent;
    while (dest !is null) {
        commands ~= dest;
        dest = dest.parent;
    }

    string[] elements;

    foreach_reverse(command; commands) {
        elements ~= command.name;

        foreach (opt; command.options.filter!(o => o.isRequired)) {
            elements ~= optionUsage(opt);
        }

        foreach (arg; command.arguments.filter!(o => o.isRequired)) {
            elements ~= argUsage(arg);
        }
    }

    elements ~= target.name;

    return elements.join(" ");
}

private string optionNames(T)(T o) {
    string names = "";

    if (o.abbrev) {
        names ~= "-" ~ o.abbrev;
    }
    else {
        names ~= "    ";
    }

    if (o.full) {
        if (o.abbrev) {
            names ~= ", ";
        }
        names ~= "--%s".format(o.full);
    }

    return names;
}

private string optionUsage(IOption o) {
    string result;

    if (o.abbrev) {
        result = "-%s".format(o.abbrev);
    }
    else {
        result = "--%s".format(o.full);
    }

    if (cast(Option)o) {
        result = "%s %s%s%s".format(result, ansi("4"), (cast(Option)o).tag, ansi("0"));
    }

    if (!o.isRequired) {
        result = "[%s]".format(result);
    }

    return result;
}

private string argUsage(Argument arg) {
    return (arg.isRequired ? "<%s>" : "[%s]").format(arg.name);
}


private string ansi(string code) {
    version(Windows) {
        return "";
    }
    version(Posix) {
        import core.sys.posix.unistd : isatty, STDOUT_FILENO;

        if (isatty(STDOUT_FILENO)) {
            return "\033[%sm".format(code);
        }

        return "";
    }

    assert(0);
}
