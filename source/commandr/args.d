/**
 * Parsed arguments module.
 *
 * This module contains functionality for handling the parsed command line arguments.
 *
 * `ProgramArgs` instance is created and returned by `parse` function. It contains values of flags,
 * options and arguments, which can be read with `.flag`, `.option` and `.arg` functions respectively.
 * Those functions work on _unique names_, not on option full/short names such as `-l` or `--help`.
 *
 * For repeating options and arguments, plural form functions can be used: `.options`, `.args`,
 * which return all values rather than last one.
 *
 * When a command or program has sub-commands returned `ProgramArgs` object forms a hierarchy,
 * where every subcommand is another instance of `ProgramArgs`, starting from root which is program args, going down
 * to selected sub-command.
 *
 * To simplify working with subcommands, you can use `on` command that allows to register command handlers
 * with a simple interface. E.g. consider git-like tool:
 *
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
 * auto programArgs = program.parse(args);
 * programArgs
 *   .on("branch", (args) {
 *       writeln("verbosity: ", args.flag("verbose"));
 *       args.on("rm", (args) { writeln("removing branch ", args.arg("name")); })
 *           .on("add", (args) { writeln("adding branch", args.arg("name")); })
 *   })
 * ---
 *
 * See_Also:
 *  ProgramArgs
 */
module commandr.args;

import commandr.program;


/**
 * Parsed program/command arguments.
 *
 * Note: All functions here work on flag/option/argument names, not short or long names.
 * option -> options multi
 * names
 * commands
 */
public class ProgramArgs {
    /// Program or command name
    public string name;

    package {
        int[string] _flags;
        string[][string] _options;
        string[][string] _args;
        string[] _args_rest;
        ProgramArgs _parent;
        ProgramArgs _command;
    }

    package ProgramArgs copy() {
        ProgramArgs a = new ProgramArgs();
        a._flags = _flags.dup;
        a._options = _options.dup;
        a._args = _args.dup;
        return a;
    }

    /**
     * Checks for flag value.
     *
     * Params:
     *   name - flag name to check
     *
     * Returns:
     *  true if flag has been passed at least once, false otherwise.
     *
     * See_Also:
     *  occurencesOf
     */
    public bool hasFlag(string name) {
        return ((name in _flags) != null && _flags[name] > 0);
    }

    /// ditto
    public alias flag = hasFlag;

    /**
     * Gets number of flag occurences.
     *
     * For non-repeating flags, returns either 0 or 1.
     *
     * Params:
     *  name - flag name to check
     *
     * Returns:
     *  Number of flag occurences, 0 on none.
     *
     * See_Also:
     *  hasFlag, flag
     */
    public int occurencesOf(string name) {
        if (!hasFlag(name)) {
            return 0;
        }
        return _flags[name];
    }

    /**
     * Gets option value.
     *
     * In case of repeating option, returns last value.
     *
     * Params:
     *   name - name of option to get
     *   defaultValue - default value if option is not set
     *
     * Returns:
     *   Last option specified, or defaultValue if none
     *
     * See_Also:
     *  options, optionAll
     */
    public string option(string name, string defaultValue = null) {
        string[]* entryPtr = name in _options;
        if (!entryPtr) {
            return defaultValue;
        }

        if ((*entryPtr).length == 0) {
            return defaultValue;
        }

        return (*entryPtr)[$-1];
    }

    /**
     * Gets all option values.
     *
     * In case of non-repeating option, returns array with one value.
     *
     * Params:
     *   name - name of option to get
     *   defaultValue - default value if option is not set
     *
     * Returns:
     *   Option values, or defaultValue if none
     *
     * See_Also:
     *  option
     */
    public string[] optionAll(string name, string[] defaultValue = null) {
        string[]* entryPtr = name in _options;
        if (!entryPtr) {
            return defaultValue;
        }
        return *entryPtr;
    }

    /// ditto
    alias options = optionAll;

    /**
     * Gets argument value.
     *
     * In case of repeating arguments, returns last value.
     *
     * Params:
     *   name - name of argument to get
     *   defaultValue - default value if argument is missing
     *
     * Returns:
     *   Argument values, or defaultValue if none
     *
     * See_Also:
     *  args, argAll
     */
    public string arg(string name, string defaultValue = null) {
        string[]* entryPtr = name in _args;
        if (!entryPtr) {
            return defaultValue;
        }

        if ((*entryPtr).length == 0) {
            return defaultValue;
        }

        return (*entryPtr)[$-1];
    }

    /**
     * Gets all argument values.
     *
     * In case of non-repeating arguments, returns array with one value.
     *
     * Params:
     *   name - name of argument to get
     *   defaultValue - default value if argument is missing
     *
     * Returns:
     *   Argument values, or defaultValue if none
     *
     * See_Also:
     *  arg
     */
    public string[] argAll(string name, string[] defaultValue = null) {
        string[]* entryPtr = name in _args;
        if (!entryPtr) {
            return defaultValue;
        }
        return *entryPtr;
    }

    /// ditto
    alias args = argAll;

    /**
     * Rest (unparsed) arguments.
     *
     * Useful, if you need to access unparsed arguments,
     * usually supplied after '--'.
     *
     * Returns:
     *   array of arguments that were not handled by parser
     *
     * Examples:
     * ---
     * auto args = ["my-command", "--opt", "arg", "--", "other-arg", "o-arg"];
     * auto res = parse(args);
     *
     * // Not we can access unparsed args as res.argsRest
     * assert(res.argsRest == ["other-arg", "o-arg"])
     * ---
     */
    public string[] argsRest() {
        return _args_rest;
    }

    /**
     * Gets subcommand arguments.
     *
     * See_Also:
     *   on, parent
     */
    public ProgramArgs command() {
        return _command;
    }

    /**
     * Gets parent `ProgramArgs`, if any.
     *
     * See_Also:
     *   command
     */
    public ProgramArgs parent() {
        return _parent;
    }

    /**
     * Calls `handler` if user specified `command` subcommand.
     *
     * Example:
     * ---
     * auto a = new Program()
     *      .add(new Command("test"))
     *      .parse(args);
     *
     * a.on("test", (a) {
     *     writeln("Test!");
     * });
     * ---
     */
    public typeof(this) on(string command, scope void delegate(ProgramArgs args) handler) {
        if (_command !is null && _command.name == command) {
            handler(_command);
        }

        return this;
    }
}
