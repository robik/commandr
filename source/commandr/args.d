module commandr.args;

import std.variant : Algebraic;
import commandr.program;


struct ProgramArgs {
    package {
        int[string] _flags;
        string[][string] _options;
        string[][string] _args;
    }

    public bool hasFlag(string name) {
        return (name in _flags) != null && _flags[name] > 0;
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
}
