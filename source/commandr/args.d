module commandr.args;

import commandr.program;
import std.variant : Algebraic;
import std.typecons : Nullable;


class ProgramArgs {
    public string name;

    package {
        int[string] _flags;
        string[][string] _options;
        string[][string] _args;
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

    public bool hasFlag(string name) {
        return ((name in _flags) != null && _flags[name] > 0);
    }
    public alias flag = hasFlag;

    public int occurencesOf(string name) {
        if (!hasFlag(name)) {
            return 0;
        }
        return _flags[name];
    }

    public string option(string name, string defaultValue = null) {
        string[]* entryPtr = name in _options;
        if (!entryPtr) {
            return defaultValue;
        }

        if ((*entryPtr).length == 0) {
            return defaultValue;
        }

        return (*entryPtr)[0];
    }

    public string[] optionAll(string name, string[] defaultValue = null) {
        string[]* entryPtr = name in _options;
        if (!entryPtr) {
            return defaultValue;
        }
        return *entryPtr;
    }
    alias options = optionAll;


    public string arg(string name, string defaultValue = null) {
        string[]* entryPtr = name in _args;
        if (!entryPtr) {
            return defaultValue;
        }

        if ((*entryPtr).length == 0) {
            return defaultValue;
        }

        return (*entryPtr)[0];
    }

    public string[] argAll(string name, string[] defaultValue = null) {
        string[]* entryPtr = name in _args;
        if (!entryPtr) {
            return defaultValue;
        }
        return *entryPtr;
    }
    alias args = argAll;

    public ProgramArgs command() {
        return _command;
    }

    public ProgramArgs parent() {
        return _parent;
    }

    public typeof(this) on(string command, scope void delegate(ProgramArgs args) handler) {
        if (_command !is null && _command.name == command) {
            handler(_command);
        }

        return this;
    }
}
