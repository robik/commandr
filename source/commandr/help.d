module commandr.help;

import commandr.program;
import commandr.option;
import std.algorithm : filter, map;
import std.array : join;
import std.stdio : writefln, writeln, write;
import std.string : format;
import std.range : chain, empty;


struct HelpOutput {
    bool colors;
    int indent = 20;
}

void printHelp(T)(T program) {
    static if (is(T == Program)) {
        writefln("%s: %s \033[2m(%s)\033[0m", program.name, program.summary, program.version_);
        writeln();
    }
    else {
        writefln("%s: %s", program.chain.join(" "), program.summary);
        writeln();
    }

    writeln("\033[1mUSAGE\033[0m");
    write("  $ "); // prefix for usage
    program.printUsage();
    writeln();

    if (!program.flags.empty) {
        writeln("\033[1mFLAGS\033[0m");
        foreach(flag; program.flags) {
            flag.printHelp();
        }
        writeln();
    }

    if (!program.options.empty) {
        writeln("\033[1mOPTIONS\033[0m");
        foreach(option; program.options) {
            option.printHelp();
        }
        writeln();
    }

    if (!program.arguments.empty) {
        writeln("\033[1mARGUMENTS\033[0m");
        foreach(arg; program.arguments) {
            arg.printHelp();
        }
        writeln();
    }

    if (!program.commands.empty) {
        writeln("\033[1mSUB-COMMANDS\033[0m");
        foreach(key, command; program.commands) {
            writefln("  %-28s%s", key, command.summary);
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
        command.chain.join(" "),
        optionsUsage, 
        args.empty ? "" : args ~ " ",
        commands
    );
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
    else {
        result = "[%s]".format(result);
    }
    return result;
}

private string argUsage(Argument arg) {
    return (arg.isRequired ? "<%s>" : "[%s]").format(arg.name);
}