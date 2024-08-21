/**
 * Program data model
 *
 * This module along with `commandr.option` contains all types needed to build
 * your program model - program options, flags, arguments and all subcommands.
 *
 * After creating your program model, you can use it to:
 *  - parse the arguments with `parse` or `parseArgs`
 *  - print help with `printHelp` or just the usage with `printUsage`
 *  - create completion script with `createBashCompletionScript`
 *
 * Examples:
 * ---
 * auto program = new Program("grit")
 *         .add(new Flag("v", "verbose", "verbosity"))
 *         .add(new Command("branch", "branch management")
 *             .add(new Command("add", "adds branch")
 *                 .add(new Argument("name"))
 *             )
 *             .add(new Command("rm", "removes branch")
 *                 .add(new Argument("name"))
 *             )
 *         )
 *      ;
 * ---
 *
 * See_Also:
 *   `Command`, `Program`, `parse`
 */
module commandr.program;

import commandr.option;
import commandr.utils;
import std.algorithm : all, reverse, map, filter;
import std.ascii : isAlphaNum;
import std.array : array;
import std.range : empty, chainRanges = chain;
import std.string : format;


/**
 * Thrown when program definition contains error.
 *
 * Errors include (but not limited to): duplicate entry name, option with no short and no long value.
 */
public class InvalidProgramException : Exception {
    /// Creates new instance of InvalidProgramException
    public this(string msg) nothrow pure @safe {
        super(msg);
    }
}

/**
 * Represents a command.
 *
 * Commands contain basic information such as name, version summary as well as
 * flags, options, arguments and sub-commands.
 *
 * `Program` is a `Command` as well, thus all methods are available in `Program`.
 *
 * See_Also:
 *   `Program`
 */
public class Command {
    private string _name;
    private string _version;
    private string _summary;
    private string _topic;
    private string _topicStart;
    private Object[string] _nameMap;
    private Flag[] _flags;
    private Option[] _options;
    private Argument[] _arguments;
    private Command[string] _commands;
    private Command _parent;
    private string _defaultCommand;

    /**
     * Creates new instance of Command.
     *
     * Params:
     *   name - command name
     *   summary - command summary (one-liner)
     *   version_ - command version
     */
    public this(string name, string summary = null, string version_ = "1.0") pure @safe {
        this._name = name;
        this._summary = summary;
        this._version = version_;
        this.add(new Flag("h", "help", "prints help"));
    }

    /**
     * Sets command name
     *
     * Params:
     *   name - unique name
     */
    public typeof(this) name(string name) nothrow pure @nogc @safe {
        this._name = name;
        return this;
    }

    /**
     * Program name
     */
    public string name() nothrow pure @nogc @safe {
        return this._name;
    }

    /**
     * Sets command version
     */
    public typeof(this) version_(string version_) nothrow pure @nogc @safe {
        this._version = version_;
        return this;
    }

    /**
     * Program version
     */
    public string version_() nothrow pure @nogc @safe {
        return this._version;
    }

    /**
     * Sets program summary (one-liner)
     */
    public typeof(this) summary(string summary) nothrow pure @nogc @safe {
        this._summary = summary;
        return this;
    }

    /**
     * Program summary
     */
    public string summary() nothrow pure @nogc @safe {
        return this._summary;
    }


    /**
     * Adds option
     *
     * Throws:
     *   `InvalidProgramException`
     */
    public typeof(this) add(Option option) pure @safe {
        validateName(option.name);
        validateOption(option);

        if (option.isRequired && option.defaultValue) {
            throw new InvalidProgramException("cannot have required option with default value");
        }

        _options ~= option;
        _nameMap[option.name] = option;
        return this;
    }

    /**
     * Command options
     */
    public Option[] options() nothrow pure @nogc @safe {
        return this._options;
    }

    /**
     * Adds command flag
     *
     * Throws:
     *   `InvalidProgramException`
     */
    public typeof(this) add(Flag flag) pure @safe {
        validateName(flag.name);
        validateOption(flag);

        if (flag.defaultValue) {
            throw new InvalidProgramException("flag %s cannot have default value".format(flag.name));
        }

        if (flag.isRequired) {
            throw new InvalidProgramException("flag %s cannot be required".format(flag.name));
        }

        if (flag.validators) {
            throw new InvalidProgramException("flag %s cannot have validators".format(flag.name));
        }

        _flags ~= flag;
        _nameMap[flag.name] = flag;
        return this;
    }

    /**
     * Command flags
     */
    public Flag[] flags() nothrow pure @nogc @safe {
        return this._flags;
    }

    /**
     * Adds command argument
     *
     * Throws:
     *   `InvalidProgramException`
     */
    public typeof(this) add(Argument argument) pure @safe {
        validateName(argument.name);

        if (_arguments.length && _arguments[$-1].isRepeating) {
            throw new InvalidProgramException("cannot add arguments past repeating");
        }

        if (argument.isRequired && _arguments.length > 0 && !_arguments[$-1].isRequired) {
            throw new InvalidProgramException("cannot add required argument past optional one");
        }

        if (argument.isRequired && argument.defaultValue) {
            throw new InvalidProgramException("cannot have required argument with default value");
        }

        this._arguments ~= argument;
        _nameMap[argument.name] = argument;
        return this;
    }

    /**
     * Command arguments
     */
    public Argument[] arguments() nothrow pure @nogc @safe {
        return this._arguments;
    }

    /**
     * Registers subcommand
     *
     * Throws:
     *   `InvalidProgramException`
     */
    public typeof(this) add(Command command) pure @safe {
        if (command.name in this._commands) {
            throw new InvalidProgramException("duplicate command %s".format(command.name));
        }

        // this is also checked by adding argument, but we want better error message
        if (!_arguments.empty && _arguments[$-1].isRepeating) {
            throw new InvalidProgramException("cannot have sub-commands and repeating argument");
        }

        if (!_arguments.empty && !_arguments[$-1].isRequired) {
            throw new InvalidProgramException("cannot have sub-commands and non-required argument");
        }

        // TODO: may be update only if command do not have topic yet,
        //       or only when _topicStart is set.
        //       Because otherwise, topic set on command is overwritten here.
        command._topic = this._topicStart;
        command._parent = this;
        _commands[command.name] = command;

        return this;
    }

    /**
     * Command sub-commands
     */
    public Command[string] commands() nothrow pure @nogc @safe {
        return this._commands;
    }

    /**
     * Sets default command.
     */
    public typeof(this) defaultCommand(string name) pure @safe {
        if (name !is null) {
            if ((name in _commands) is null) {
                throw new InvalidProgramException("setting default command to non-existing one");
            }
        }
        this._defaultCommand = name;

        return this;
    }

    /**
     * Gets default command
     */
    public string defaultCommand() nothrow pure @safe @nogc {
        return this._defaultCommand;
    }

    public typeof(this) topicGroup(string topic) pure @safe {
        this._topicStart = topic;
        return this;
    }

    public typeof(this) topic(string topic) nothrow pure @safe @nogc {
        this._topic = topic;
        return this;
    }

    public string topic() nothrow pure @safe @nogc {
        return _topic;
    }

    /**
     * Gets command chain.
     *
     * Chain is a array of strings which contains all parent command names.
     * For a deeply nested sub command like `git branch add`, `add` sub-command
     * chain would return `["git", "branch", "add"]`.
     */
    public string[] chain() pure nothrow @safe {
        string[] chain = [this.name];
        Command curr = this._parent;
        while (curr !is null) {
            chain ~= curr.name;
            curr = curr._parent;
        }

        chain.reverse();
        return chain;
    }

    public Command parent() nothrow pure @safe @nogc {
        return _parent;
    }

    public string[] fullNames() nothrow pure @safe {
        return chainRanges(
            _flags.map!(f => f.full),
            _options.map!(o => o.full)
        ).filter!`a && a.length`.array;
    }

    public string[] abbrevations() nothrow pure @safe {
        return chainRanges(
            _flags.map!(f => f.abbrev),
            _options.map!(o => o.abbrev)
        ).filter!`a && a.length`.array;
    }

    private void addBasicOptions() {
        this.add(new Flag(null, "version", "prints version"));
    }

    private void validateName(string name) pure @safe {
        if (!name) {
            throw new InvalidProgramException("name cannot be empty");
        }

        if (name[0] == '-')
            throw new InvalidProgramException("invalid name '%s' -- cannot begin with '-'".format(name));

        if (!name.all!(c => isAlphaNum(c) || c == '_' || c == '-')()) {
            throw new InvalidProgramException("invalid name '%s' passed".format(name));
        }

        auto entryPtr = name in _nameMap;
        if (entryPtr !is null) {
            throw new InvalidProgramException(
                "duplicate name %s which is already used".format(name)
            );
        }
    }

    private void validateOption(IOption option) pure @safe {
        if (!option.abbrev && !option.full) {
            throw new InvalidProgramException(
                "option/flag %s must have either long or short form".format(option.name)
            );
        }

        if (option.abbrev) {
            auto flag = this.getFlagByShort(option.abbrev);
            if (!flag.isNull) {
                throw new InvalidProgramException(
                    "duplicate abbrevation -%s, flag %s already uses it".format(option.abbrev, flag.get().name)
                );
            }

            auto other = this.getOptionByShort(option.abbrev);
            if (!other.isNull) {
                throw new InvalidProgramException(
                    "duplicate abbrevation -%s, option %s already uses it".format(option.abbrev, other.get().name)
                );
            }
        }

        if (option.full) {
            auto flag = this.getFlagByFull(option.full);
            if (!flag.isNull) {
                throw new InvalidProgramException(
                    "duplicate -%s, flag %s with this already exists".format(option.full, flag.get().name)
                );
            }

            auto other = this.getOptionByFull(option.full);
            if (!other.isNull) {
                throw new InvalidProgramException(
                    "duplicate --%s, option %s with this already exists".format(option.full, other.get().name)
                );
            }
        }

        if (option.isRequired && option.defaultValue) {
            throw new InvalidProgramException("cannot have required option with default value");
        }
    }
}

/**
 * Represents program.
 *
 * This is the entry-point for building your program model.
 */
public class Program: Command {
    private string _binaryName;
    private string[] _authors;

    /**
     * Creates new instance of `Program`.
     *
     * Params:
     *   name - Program name
     *   version_ - Program version
     */
    public this(string name, string version_ = "1.0") {
        super(name, null, version_);
        this.addBasicOptions();
    }

    /**
     * Sets program name
     */
    public override typeof(this) name(string name) nothrow pure @nogc @safe {
        return cast(Program)super.name(name);
    }

    /**
     * Program name
     */
    public override string name() const nothrow pure @nogc @safe {
        return this._name;
    }

    /**
     * Sets program version
     */
    public override typeof(this) version_(string version_) nothrow pure @nogc @safe {
        return cast(Program)super.version_(version_);
    }

    /**
     * Program version
     */
    public override string version_() const nothrow pure @nogc @safe {
        return this._version;
    }

    /**
     * Sets program summary (one-liner)
     */
    public override typeof(this) summary(string summary) nothrow pure @nogc @safe {
        return cast(Program)super.summary(summary);
    }

    /**
     * Program summary (one-liner)
     */
    public override string summary() nothrow pure @nogc @safe {
        return this._summary;
    }

    /// Proxy call to `Command.add` returning `Program`.
    public typeof(this) add(T: IEntry)(T data) pure @safe {
        super.add(data);
        return this;
    }

    public override typeof(this) add(Command command) pure @safe {
        super.add(command);
        return this;
    }

    public override typeof(this) defaultCommand(string name) pure @safe {
        super.defaultCommand(name);
        return this;
    }

    public override string defaultCommand() nothrow pure @safe @nogc {
        return this._defaultCommand;
    }

    /**
     * Sets program binary name
     */
    public typeof(this) binaryName(string binaryName) nothrow pure @nogc @safe {
        this._binaryName = binaryName;
        return this;
    }

    /**
     * Program binary name
     */
    public string binaryName() const nothrow pure @nogc @safe {
        return (this._binaryName !is null) ? this._binaryName : this._name;
    }

    /**
     * Adds program author
     */
    public typeof(this) author(string author) nothrow pure @safe {
        this._authors ~= author;
        return this;
    }

    /**
     * Sets program authors
     */
    public typeof(this) authors(string[] authors) nothrow pure @nogc @safe {
        this._authors = authors;
        return this;
    }

    /**
     * Program authors
     */
    public string[] authors() nothrow pure @nogc @safe {
        return this._authors;
    }

    /**
     * Sets topic group for the following commands.
     */
    public override typeof(this) topicGroup(string topic) pure @safe {
        super.topicGroup(topic);
        return this;
    }

    /**
     * Sets topic group for this command.
     */
    public override typeof(this) topic(string topic) nothrow pure @safe @nogc {
        super.topic(topic);
        return this;
    }

    /**
     * Topic group for this command.
     */
    public override string topic() nothrow pure @safe @nogc {
        return _topic;
    }
}

unittest {
    import std.range : empty;

    auto program = new Program("test");
    assert(program.name == "test");
    assert(program.binaryName == "test");
    assert(program.version_ == "1.0");
    assert(program.summary is null);
    assert(program.authors.empty);
    assert(program.flags.length == 2);
    assert(program.flags[0].name == "help");
    assert(program.flags[0].abbrev == "h");
    assert(program.flags[0].full == "help");
    assert(program.flags[1].name == "version");
    assert(program.flags[1].abbrev is null);
    assert(program.flags[1].full == "version");
    assert(program.options.empty);
    assert(program.arguments.empty);
}

unittest {
    auto program = new Program("test").name("bar");
    assert(program.name == "bar");
    assert(program.binaryName == "bar");
}

unittest {
    auto program = new Program("test", "0.1");
    assert(program.version_ == "0.1");
}

unittest {
    auto program = new Program("test", "0.1").version_("2.0").version_("kappa");
    assert(program.version_ == "kappa");
}

unittest {
    auto program = new Program("test").binaryName("kappa");
    assert(program.name == "test");
    assert(program.binaryName == "kappa");
}

// name conflicts
unittest {
    import std.exception : assertThrown;

    // FLAGS
    // flag-flag
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Flag("a", "aaa", "desc").name("nnn"))
            .add(new Flag("b", "bbb", "desc").name("nnn"))
    );

    // flag-option
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Flag("a", "aaa", "desc").name("nnn"))
            .add(new Option("b", "bbb", "desc").name("nnn"))
    );

    // flag-argument
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Flag("a", "aaa", "desc").name("nnn"))
            .add(new Argument("nnn"))
    );


    // OPTIONS
    // option-flag
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Option("a", "aaa", "desc").name("nnn"))
            .add(new Flag("b", "bbb", "desc").name("nnn"))
    );

    // option-option
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Option("a", "aaa", "desc").name("nnn"))
            .add(new Option("b", "bbb", "desc").name("nnn"))
    );

    // option-argument
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Option("a", "aaa", "desc").name("nnn"))
            .add(new Argument("nnn"))
    );


    // ARGUMENTS
    // argument-flag
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Argument("nnn"))
            .add(new Flag("b", "bbb", "desc").name("nnn"))
    );

    // argument-option
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Argument("nnn"))
            .add(new Option("b", "bbb", "desc").name("nnn"))
    );

    // argument-argument
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Argument("nnn"))
            .add(new Argument("nnn"))
    );
}

// abbrev conflicts
unittest {
    import std.exception : assertThrown;

    // FLAGS
    // flag-flag
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Flag("a", "aaa", "desc"))
            .add(new Flag("a", "bbb", "desc"))
    );

    // flag-option
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Flag("a", "aaa", "desc"))
            .add(new Option("a", "bbb", "desc"))
    );

    // FLAGS
    // option-flag
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Option("a", "aaa", "desc"))
            .add(new Flag("a", "bbb", "desc"))
    );

    // option-option
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Option("a", "aaa", "desc"))
            .add(new Option("a", "bbb", "desc"))
    );
}

// full name conflicts
unittest {
    import std.exception : assertThrown;

    // FLAGS
    // flag-flag
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Flag("a", "aaa", "desc"))
            .add(new Flag("b", "aaa", "desc"))
    );

    // flag-option
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Flag("a", "aaa", "desc"))
            .add(new Option("b", "aaa", "desc"))
    );

    // FLAGS
    // option-flag
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Option("a", "aaa", "desc"))
            .add(new Flag("b", "aaa", "desc"))
    );

    // option-option
    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Option("a", "aaa", "desc"))
            .add(new Option("b", "aaa", "desc"))
    );
}

// repeating
unittest {
    import std.exception : assertThrown;

    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Argument("file", "path").repeating)
            .add(new Argument("dir", "desc"))
    );
}

// invalid option
unittest {
    import std.exception : assertThrown;

    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Flag(null, null, ""))
    );

    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Option(null, null, ""))
    );
}

// required args out of order
unittest {
    import std.exception : assertThrown;

    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Argument("file", "path").optional)
            .add(new Argument("dir", "desc"))
    );
}

// default required
unittest {
    import std.exception : assertThrown;

    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Option("d", "dir", "desc").defaultValue("test").required)
    );

    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Argument("dir", "desc").defaultValue("test").required)
    );
}

// flags
unittest {
    import std.exception : assertThrown;
    import commandr.validators;

    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Flag("a", "bb", "desc")
                .acceptsValues(["a"]))
    );
}

// subcommands
unittest {
    import std.exception : assertThrown;

    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Argument("test", "").defaultValue("test"))
            .add(new Command("a"))
            .add(new Command("b"))
    );
}

// default command
unittest {
    import std.exception : assertThrown, assertNotThrown;
    import commandr.validators;

    assertThrown!InvalidProgramException(
        new Program("test")
            .defaultCommand("a")
            .add(new Command("a", "desc"))
    );

    assertThrown!InvalidProgramException(
        new Program("test")
            .add(new Command("a", "desc"))
            .defaultCommand("b")
    );

    assertNotThrown!InvalidProgramException(
        new Program("test")
            .add(new Command("a", "desc"))
            .defaultCommand(null)
    );
}

// topics
unittest {
    import std.exception : assertThrown, assertNotThrown;
    import commandr.validators;

    auto p = new Program("test")
            .add(new Command("a", "desc"))
            .topic("z")
            .topicGroup("general purpose")
            .add(new Command("b", "desc"))
            .add(new Command("c", "desc"))
            .topicGroup("other")
            .add(new Command("d", "desc"))
            ;

    assert(p.topic == "z");
    assert(p.commands["b"].topic == "general purpose");
    assert(p.commands["c"].topic == "general purpose");
    assert(p.commands["d"].topic == "other");
}
