module commandr.help;

import commandr.program;
import commandr.option;
import std.algorithm : filter, map, any, chunkBy, sort;
import std.array : join, array;
import std.conv : to;
import std.stdio : writefln, writeln, write;
import std.string : format;
import std.range : chain, empty;


///
struct HelpOutput {
    ///
    bool colors = true;
    // bool compact = false;

    ///
    // int maxWidth = 80;

    ///
    int indent = 24;
    ///
    int optionsLimit = 6;
    ///
    int commandLimit = 6;
}

///
void printHelp(Command program, HelpOutput output = HelpOutput.init) {
    HelpPrinter(output).printHelp(program);
}

///
void printUsage(Command program, HelpOutput output = HelpOutput.init) {
    HelpPrinter(output).printUsage(program);
}


struct HelpPrinter {
    HelpOutput config;

    public this(HelpOutput config) nothrow pure @safe {
        this.config = config;
    }

    void printHelp(Command program) {
        if (cast(Program)program) {
            writefln("%s: %s %s(%s)%s", program.name, program.summary, ansi("2"), program.version_, ansi("0"));
            writeln();
        }
        else {
            writefln("%s: %s", program.chain.join(" "), program.summary);
            writeln();
        }

        writefln("%sUSAGE%s", ansi("1"), ansi("0"));
        write("  $ "); // prefix for usage
        printUsage(program);
        writeln();

        if (!program.flags.empty) {
            writefln("%sFLAGS%s", ansi("1"), ansi("0"));
            foreach(flag; program.flags) {
                printHelp(flag);
            }
            writeln();
        }

        if (!program.options.empty) {
            writefln("%sOPTIONS%s", ansi("1"), ansi("0"));
            foreach(option; program.options) {
                printHelp(option);
            }
            writeln();
        }

        if (!program.arguments.empty) {
            writefln("%sARGUMENTS%s", ansi("1"), ansi("0"));
            foreach(arg; program.arguments) {
                printHelp(arg);
            }
            writeln();
        }

        if (program.commands.length > 0) {
            writefln("%sSUBCOMMANDS%s", ansi("1"), ansi("0"));
            printSubcommands(program.commands);
            writeln();
        }
    }

    void printUsage(Program program) {
        string optionsUsage = "[options]";

        // if there are not too many options
        if (program.options.length + program.flags.length <= config.optionsLimit) {
            optionsUsage = chain(
                program.flags.map!(f => optionUsage(f)),
                program.options.map!(o => optionUsage(o))
            ).join(" ");
        } else {
            optionsUsage ~= " " ~ program.options.filter!(o => o.isRequired).map!(o => optionUsage(o)).join(" ");
        }

        string commands = program.commands.length == 0 ? "" : (
            program.commands.length > config.commandLimit ? "COMMAND" : program.commands.keys.join("|")
        );
        string args = program.arguments.map!(a => argUsage(a)).join(" ");

        writefln("%s %s %s%s",
            program.binaryName,
            optionsUsage,
            args.empty ? "" : args ~ " ",
            commands
        );
    }

    void printUsage(Command command) {
        string optionsUsage = "[options]";
        if (command.options.length + command.flags.length <= config.optionsLimit) {
            optionsUsage = chain(
                command.flags.map!(f => optionUsage(f)),
                command.options.map!(o => optionUsage(o))
            ).join(" ");
        } else {
            optionsUsage ~= " " ~ command.options.filter!(o => o.isRequired).map!(o => optionUsage(o)).join(" ");
        }

        string commands = command.commands.length == 0 ? "" : (
            command.commands.length > config.commandLimit ? "command" : command.commands.keys.join("|")
        );
        string args = command.arguments.map!(a => argUsage(a)).join(" ");

        writefln("%s %s %s%s",
            usageChain(command),
            optionsUsage,
            args.empty ? "" : args ~ " ",
            commands
        );
    }

    private void printHelp(Flag flag) {
        string left = optionNames(flag);
        writefln("  %-"~config.indent.to!string~"s  %s%s%s", left, ansi("2"), flag.description, ansi("0"));
    }

    private void printHelp(Option option) {
        string left = optionNames(option);
        size_t length = left.length + option.tag.length + 1;
        string formatted = "%s %s%s%s".format(left, ansi("4"), option.tag, ansi("0"));
        size_t padLength = config.indent + (formatted.length - length);

        writefln("  %-"~padLength.to!string~"s  %s%s%s", formatted, ansi("2"), option.description, ansi("0"));
    }

    private void printHelp(Argument arg) {
        writefln("  %-"~config.indent.to!string~"s  %s%s%s", arg.tag, ansi("2"), arg.description, ansi("0"));
    }

    private void printSubcommands(Command[string] commands) {
        auto grouped = commands.values
            .sort!((a, b) {
                // Note, when we used chunkBy, it is expected that range
                // is already sorted by the key, thus before grouping,
                // we have to sort by topic first.
                // And then by name for better output
                // (because associative array do not preserver order).
                if (a.topic == b.topic)
                    return a.name < b.name;
                return a.topic < b.topic;
            })
            .chunkBy!(a => a.topic)
            .array;

        if (grouped.length == 1 && grouped[0][0] is null) {
            foreach(key, command; commands) {
                writefln("  %-"~config.indent.to!string~"s  %s%s%s", key, ansi("2"), command.summary, ansi("0"));
            }
        }
        else {
            foreach (entry; grouped) {
                writefln("  %s%s%s:", ansi("4"), entry[0], ansi("0"));
                foreach(command; entry[1]) {
                    writefln(
                        "    %-"~(config.indent - 2).to!string~"s  %s%s%s",
                        command.name, ansi("2"), command.summary, ansi("0")
                    );
                }
                writeln();
            }
        }
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
            elements ~= ansi("0") ~ command.name ~ ansi("2");

            foreach (opt; command.options.filter!(o => o.isRequired)) {
                elements ~= optionUsage(opt) ~ ansi("2");
            }

            foreach (arg; command.arguments.filter!(o => o.isRequired)) {
                elements ~= argUsage(arg);
            }
        }

        elements ~= ansi("0") ~ target.name;

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
        string result = o.displayName;

        if (cast(Option)o) {
            result = "%s %s%s%s".format(result, ansi("4"), (cast(Option)o).tag, ansi("0"));
        }

        if (!o.isRequired) {
            result = "[%s]".format(result);
        }

        return result;
    }

    private string argUsage(Argument arg) {
        return (arg.isRequired ? "%s" : "[%s]").format(arg.tag);
    }


    private string ansi(string code) {
        version(Windows) {
            return "";
        }
        version(Posix) {
            import core.sys.posix.unistd : isatty, STDOUT_FILENO;

            if (config.colors && isatty(STDOUT_FILENO)) {
                return "\033[%sm".format(code);
            }

            return "";
        }

        assert(0);
    }
}
