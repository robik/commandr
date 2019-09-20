module commandr.help;

import commandr.program;
import commandr.option;
import std.algorithm : filter, map;
import std.array : join;
import std.stdio : writefln, writeln, write;
import std.string : format;
import std.range : chain;


struct HelpOutput {
    bool colors;
}

void printHelp(Program program) {
    writefln("%s: %s \033[2m(%s)\033[0m", program.name, program.summary, program.version_);
    writeln();

    writeln("\033[1mUSAGE\033[0m");
    write("  $ "); // prefix for usage
    program.printUsage();
    writeln();

    if (program.flags.length > 0) {
        writeln("\033[1mFLAGS\033[0m");
        foreach(flag; program.flags) {
            flag.printHelp();
        }
        writeln();
    }

    if (program.options.length > 0) {
        writeln("\033[1mOPTIONS\033[0m");
        foreach(option; program.options) {
            option.printHelp();
        }
        writeln();
    }

    if (program.arguments.length > 0) {
        writeln("\033[1mARGUMENTS\033[0m");
        foreach(arg; program.arguments) {
            arg.printHelp();
        }
        writeln();
    }
}

void printUsage(Program program) {
    string optionsUsage = "[options]";    
    if (program.options.length + program.flags.length <= 8) {
        optionsUsage = chain(
            program.flags.map!(o => optionUsage(o)),
            program.options.map!(o => optionUsage(o))
        ).join(" ");
    }
    writefln("%s %s %s", program.binaryName, optionsUsage, program.arguments.map!(argUsage).join(" "));
}

private void printHelp(Flag flag) {
    string left = optionNames(flag);
    writefln("  %-26s  \033[2m%s\033[0m", left, flag.description);
}

private void printHelp(Option option) {
    string left = optionNames(option);

    writefln("  %-26s  \033[2m%s\033[0m", "%s=%s".format(left, option.tag), option.description);
}

private void printHelp(Argument arg) {
    writefln("  %-26s  \033[2m%s\033[0m", arg.name, arg.description);
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

private string optionUsage(T)(T o) {
    string result;

    if (o.abbrev) {
        result = "-%s".format(o.abbrev);
    }
    else {
        result = "--%s".format(o.full);
    }

    static if (is(T == Option)) {
        if (!o.isRequired) {
            result = "[%s]".format(result);
        }
    }
    return result;
}

private string argUsage(Argument arg) {
    return (arg.isRequired ? "<%s>" : "[%s]").format(arg.name);
}