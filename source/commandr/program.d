module commandr.program;

import commandr.option;
import commandr.utils;
import std.algorithm : all;
import std.ascii : isAlphaNum;
import std.string : format;


private mixin template OptionAggregate() {
    private string _name;
    private string _version;
    private string _summary;
    private Flag[] _flags;
    private Option[] _options;
    private Argument[] _arguments;
    private Command[string] _commands;
    private Program* _root;
    private string[] _chain;


    public this(string name, string summary = "", string version_ = "1.0") {
        this._name = name;
        this._summary = summary;
        this._version = version_;
        this.add(Flag("h", "help", "prints help"));
        this._chain = [_name];
    }

    /**
     * Sets program name
     */
    public typeof(this) name(string name) nothrow pure {
        this._name = name;
        return this;
    }

    /**
     * Program name
     */
    public string name() nothrow pure {
        return this._name;
    }

    /**
     * Sets program version
     */
    public typeof(this) version_(string version_) nothrow pure {
        this._version = version_;
        return this;
    }

    /**
     * Program version
     */
    public string version_() nothrow pure {
        return this._version;
    }

    /**
     * Sets program summary (one-liner)
     */
    public typeof(this) summary(string summary) nothrow pure {
        this._summary = summary;
        return this;
    }

    /**
     * Program summary
     */
    public string summary() nothrow pure {
        return this._summary;
    }


    /**
     * Adds option
     */
    public typeof(this) add(Option option) {
        validateName(option.name);
        validateAbbrev(option.abbrev);
        validateFull(option.full);

        if (option.isRequired && option.defaultValue) {
            throw new InvalidProgramException("cannot have required option with default value");
        }

        this._options ~= option;
        return this;
    }

    /**
     * Program options
     */
    public Option[] options() nothrow pure {
        return this._options;
    }

    /**
     * Adds program flag
     */
    public typeof(this) add(Flag flag) {
        validateName(flag.name);
        validateAbbrev(flag.abbrev);
        validateFull(flag.full);

        this._flags ~= flag;
        return this;
    }

    /**
     * Program flags
     */
    public Flag[] flags() nothrow pure {
        return this._flags;
    }

    /**
     * Adds program argument
     */
    public typeof(this) add(Argument argument) {
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
        return this;
    }

    /**
     * Program arguments
     */
    public Argument[] arguments() nothrow pure {
        return this._arguments;
    }

    public typeof(this) add(Command command) {
        if (command.name in this._commands) {
            throw new InvalidProgramException("duplicate command %s".format(command.name));
        }

        command._root = this._root;
        command._chain = this._chain ~ command._chain;
        _commands[command.name] = command;

        return this;
    }

    public Command[string] commands() nothrow pure {
        return this._commands;
    }

    private void validateName(string name) {
        if (!name) {
            throw new InvalidProgramException("name cannot be empty");
        }

        if (!name.all!(c => isAlphaNum(c) || c == '_')()) {
            throw new InvalidProgramException("invalid name '%s' passed".format(name));
        }

        auto flag = this.getFlagByName(name);
        if (!flag.isNull) {
            throw new InvalidProgramException(
                "duplicate name %s which is already used by a flag".format(name)
            );
        }

        auto option = this.getOptionByName(name);
        if (!option.isNull) {
            throw new InvalidProgramException(
                "duplicate name %s which is already used by an option".format(name)
            );
        }

        auto arg = this.getArgumentByName(name);
        if (!arg.isNull) {
            throw new InvalidProgramException(
                "duplicate name %s which is already used by an argument".format(name)
            );
        }
    }

    private void validateAbbrev(string abbrev) {
        if (!abbrev) {
            return;
        }

        auto flag = this.getFlagByShort(abbrev);
        if (!flag.isNull) {
            throw new InvalidProgramException(
                "duplicate abbrevation -%s, flag %s already uses it".format(abbrev, flag.get().name)
            );
        }

        auto option = this.getOptionByShort(abbrev);
        if (!option.isNull) {
            throw new InvalidProgramException(
                "duplicate abbrevation -%s, option %s already uses it".format(abbrev, option.get().name)
            );
        }
    }

    private void validateFull(string full) {
        if (!full) {
            return;
        }

        auto flag = this.getFlagByFull(full);
        if (!flag.isNull) {
            throw new InvalidProgramException(
                "duplicate -%s, flag %s with this already exists".format(full, flag.get().name)
            );
        }

        auto option = this.getOptionByFull(full);
        if (!option.isNull) {
            throw new InvalidProgramException(
                "duplicate --%s, option %s with this already exists".format(full, option.get().name)
            );
        }
    }

    public string[] chain() {
        return this._chain;
    }

    private void addBasicOptions() {
        this.add(Flag(null, "version", "prints version"));
    }
}

struct Command {
    mixin OptionAggregate;
}

struct Program {
    mixin OptionAggregate;
    private string _binaryName;
    private string[] _authors;


    public this(string name, string version_ = "1.0") {
        this._name = name;
        this._version = version_;
        this._root = &this;
        this.addBasicOptions();
    }

    /**
     * Sets program binary name
     */
    public typeof(this) binaryName(string binaryName) nothrow pure {
        this._binaryName = binaryName;
        this._chain = [binaryName];
        return this;
    }

    /**
     * Program binary name
     */
    public string binaryName() nothrow pure {
        return (this._binaryName !is null) ? this._binaryName : this._name;
    }

    /**
     * Adds program author
     */
    public typeof(this) author(string author) nothrow pure {
        this._authors ~= author;
        return this;
    }

    /**
     * Sets program authors
     */
    public typeof(this) authors(string[] authors) nothrow pure {
        this._authors = authors;
        return this;
    }

    /**
     * Program authors
     */
    public string[] authors() nothrow pure {
        return this._authors;
    }
}

unittest {
    import std.range : empty;

    auto program = Program("test");
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
    auto program = Program("test").name("bar");
    assert(program.name == "bar");
    assert(program.binaryName == "bar");
}

unittest {
    auto program = Program("test", "0.1");
    assert(program.version_ == "0.1");
}

unittest {
    auto program = Program("test", "0.1").version_("2.0").version_("kappa");
    assert(program.version_ == "kappa");
}

unittest {
    auto program = Program("test").binaryName("kappa");
    assert(program.name == "test");
    assert(program.binaryName == "kappa");
}

// name conflicts
unittest {
    import std.exception : assertThrown;

    // FLAGS
    // flag-flag
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Flag("a", "aaa", "desc").name("nnn"))
            .add(Flag("b", "bbb", "desc").name("nnn"))
    );

    // flag-option
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Flag("a", "aaa", "desc").name("nnn"))
            .add(Option("b", "bbb", "desc").name("nnn"))
    );

    // flag-argument
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Flag("a", "aaa", "desc").name("nnn"))
            .add(Argument("nnn"))
    );


    // OPTIONS
    // option-flag
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Option("a", "aaa", "desc").name("nnn"))
            .add(Flag("b", "bbb", "desc").name("nnn"))
    );

    // option-option
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Option("a", "aaa", "desc").name("nnn"))
            .add(Option("b", "bbb", "desc").name("nnn"))
    );

    // option-argument
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Option("a", "aaa", "desc").name("nnn"))
            .add(Argument("nnn"))
    );


    // ARGUMENTS
    // argument-flag
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Argument("nnn"))
            .add(Flag("b", "bbb", "desc").name("nnn"))
    );

    // argument-option
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Argument("nnn"))
            .add(Option("b", "bbb", "desc").name("nnn"))
    );

    // argument-argument
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Argument("nnn"))
            .add(Argument("nnn"))
    );
}

// abbrev conflicts
unittest {
    import std.exception : assertThrown;

    // FLAGS
    // flag-flag
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Flag("a", "aaa", "desc"))
            .add(Flag("a", "bbb", "desc"))
    );

    // flag-option
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Flag("a", "aaa", "desc"))
            .add(Option("a", "bbb", "desc"))
    );

    // FLAGS
    // option-flag
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Option("a", "aaa", "desc"))
            .add(Flag("a", "bbb", "desc"))
    );

    // option-option
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Option("a", "aaa", "desc"))
            .add(Option("a", "bbb", "desc"))
    );
}

// full name conflicts
unittest {
    import std.exception : assertThrown;

    // FLAGS
    // flag-flag
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Flag("a", "aaa", "desc"))
            .add(Flag("b", "aaa", "desc"))
    );

    // flag-option
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Flag("a", "aaa", "desc"))
            .add(Option("b", "aaa", "desc"))
    );

    // FLAGS
    // option-flag
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Option("a", "aaa", "desc"))
            .add(Flag("b", "aaa", "desc"))
    );

    // option-option
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Option("a", "aaa", "desc"))
            .add(Option("b", "aaa", "desc"))
    );
}

unittest {
    import std.exception : assertThrown;

    // repating
    assertThrown!InvalidProgramException(
        Program("test")
            .add(Argument("file", "path").repeating)
            .add(Argument("dir", "desc"))
    );
}

// required args out of order
unittest {
    import std.exception : assertThrown;

    assertThrown!InvalidProgramException(
        Program("test")
            .add(Argument("file", "path"))
            .add(Argument("dir", "desc").required)
    );
}

// default required
unittest {
    import std.exception : assertThrown;

    assertThrown!InvalidProgramException(
        Program("test")
            .add(Option("d", "dir", "desc").required.defaultValue("test"))
    );

    assertThrown!InvalidProgramException(
        Program("test")
            .add(Argument("dir", "desc").required.defaultValue("test"))
    );
}