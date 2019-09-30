/**
 * User input validation.
 *
 * This module contains core functionality for veryfing values as well as some
 * basic validators.
 *
 * Options and arguments (no flags, as they cannot take value) can have any number of validators attached.
 * Validators are objects that verify user input after parsing values - every validator is run once
 * per option/argument that it is attached to with complete vector of user input (e.g. for repeating values).
 *
 * Validators are ran in order they are defined aborting on first failure with `ValidationException`.
 * Exception contains the validator that caused the exception (optionally) along with error message.
 *
 * Validators can be attached using `validate` method, or using helper methods in form of `accepts*`:
 *
 * ---
 * new Program("test")
 *   .add(new Option("t", "test", "description")
 *       .acceptsValues(["test", "bar"])
 *   )
 *   // both are equivalent
 *   .add(new Option("T", "test2", "description")
 *       .validate(new EnumValidator(["test", "bar"]))
 *   )
 * ---
 *
 * ## Custom Validators
 *
 * To add custom validating logic, you can either create custom Validator class that implements `IValidator` interface
 * or use `DelegateValidator` passing delegate with your validating logic:
 *
 * ---
 * new Program("test")
 *   .add(new Option("t", "test", "description")
 *       .validateWith((entry, value) {
 *           if (value == "test") throw new ValidationException("Value must be test");
 *       })
 *       .validateWith(arg => isNumericString(arg), "must be numeric")
 *   )
 * ---
 *
 * Validators already provided:
 *   - `EnumValidator` (`acceptsValues`)
 *   - `FileSystemValidator` (`acceptsFiles`, `acceptsDirectories`)
 *   - `DelegateValidator` (`validateWith`, `validateEachWith`)
 *
 * See_Also:
 *  IValidator, ValidationException
 */
module commandr.validators;

import commandr.option : IEntry, InvalidArgumentsException;
import commandr.utils : getEntryKindName, matchingCandidate;
import std.algorithm : canFind, any, each;
import std.array : join;
import std.string : format;
import std.file : exists, isDir, isFile;
import std.typecons : Nullable;


/**
 * Validation error.
 *
 * This exception is thrown when an invalid value has been passed to an option/value
 * that has validators assigned (manually or through accepts* functions).
 *
 * Exception is thrown on first validator failure. Validators are run in definition order.
 *
 * Because this exception extends `InvalidArgumentsException`, there's no need to
 * catch it explicitly unless needed.
 */
public class ValidationException: InvalidArgumentsException {
    /**
     * Validator that caused the error.
     */
    IValidator validator;

    /// Creates new instance of ValidationException
    public this(IValidator validator, string msg) nothrow pure @safe @nogc {
        super(msg);
        this.validator = validator;
    }
}

/**
 * Interface for validators.
 */
public interface IValidator {
    /**
     * Checks whenever specified input is valid.
     *
     * Params:
     *   entry - Information about checked entry.
     *   values - Array of values to validate.
     *
     * Throws:
     *   ValidationException
     */
    void validate(IEntry entry, string[] values);
}


/**
 * Input whitelist check.
 *
 * Validates whenever input is contained in list of valid/accepted values.
 *
 * Examples:
 * ---
 * new Program("test")
 *      .add(new Option("s", "scope", "working scope")
 *          .acceptsValues(["user", "system"])
 *      )
 * ---
 *
 * See_Also:
 *   acceptsValues
 */
public class EnumValidator: IValidator {
    // TODO: Throw InvalidValidatorException: InvalidProgramException on empty matches?
    /**
     * List of allowed values.
     */
    string[] allowedValues;

    /// Creates new instance of EnumValidator
    public this(string[] values) nothrow pure @safe @nogc {
        this.allowedValues = values;
    }

    /// Validates input
    public void validate(IEntry entry, string[] args) @safe {
        foreach(arg; args) {
            if (!allowedValues.canFind(arg)) {
                string suggestion = allowedValues.matchingCandidate(arg);
                if (suggestion) {
                    suggestion = " (did you mean %s?)".format(suggestion);
                } else {
                    suggestion = "";
                }

                throw new ValidationException(this,
                    "%s %s must be one of following values: %s%s".format(
                        entry.getEntryKindName(), entry.name, allowedValues.join(", "), suggestion
                    )
                );
            }
        }
    }
}

/**
 * Helper function to define allowed values for an option or argument.
 *
 * This function is meant to be used with UFCS, so that it can be placed
 * within option definition chain.
 *
 * Params:
 *   entry - entry to define allowed values to
 *   values - list of allowed values
 *
 * Examples:
 * ---
 * new Program("test")
 *      .add(new Option("s", "scope", "working scope")
 *          .acceptsValues(["user", "system"])
 *      )
 * ---
 *
 * See_Also:
 *   EnumValidator
 */
public T acceptsValues(T : IEntry)(T entry, string[] values) @safe {
    return entry.validate(new EnumValidator(values));
}


/**
 * Specified expected entry type for `FileSystemValidator`.
 */
public enum FileType {
    ///
    Directory,

    ///
    File
}


/**
 * FileSystem validator.
 *
 * See_Also:
 *  acceptsFiles, acceptsDirectories, acceptsPath
 */
public class FileSystemValidator: IValidator {
    /// Exists contraint
    Nullable!bool exists;

    /// Entry type contraint
    Nullable!FileType type;

    /**
     * Creates new FileSystem validator.
     *
     * This constructor creates a `FileSystemValidator` that checks only
     * whenever the path points to a existing (or not) item.
     *
     * Params:
     *  exists - Whenever passed path should exist.
     */
    public this(bool exists) nothrow pure @safe @nogc {
        this.exists = exists;
    }

    /**
     * Creates new FileSystem validator.
     *
     * This constructor creates a `FileSystemValidator` that checks
     * whenever the path points to a existing item of specified type.
     *
     * Params:
     *  type - Expected item type
     */
    public this(FileType type) {
        this.exists = true;
        this.type = type;
    }

    /// Validates input
    public void validate(IEntry entry, string[] args) {
        foreach (arg; args) {
            if (!this.exists.isNull) {
                validateExists(entry, arg, this.exists.get());
            }

            if (!this.type.isNull) {
                validateType(entry, arg, this.type.get());
            }
        }
    }

    private void validateExists(IEntry entry, string arg, bool exists) {
        if (arg.exists() == exists) {
            return;
        }

        throw new ValidationException(this,
            "%s %s value must point to a %s that %sexists".format(
                entry.getEntryKindName(),
                entry.name,
                this.type.isNull
                    ? "file/directory"
                    : this.type.get() == FileType.Directory ? "directory" : "file",
                exists ? "" : "not "
            )
        );
    }

    private void validateType(IEntry entry, string arg, FileType type) {
        switch (type) {
            case FileType.File:
                if (!arg.isFile) {
                    throw new ValidationException(this,
                        "value specified in %s %s must be a valid file".format(
                            entry.getEntryKindName(), entry.name,
                        )
                    );
                }
                break;

            case FileType.Directory:
                if (!arg.isDir) {
                    throw new ValidationException(this,
                        "value specified in %s %s must be a valid file".format(
                            entry.getEntryKindName(), entry.name,
                        )
                    );
                }
                break;

            default:
                assert(0);
        }
    }
}

/**
 * Helper function to require passing a path pointing to existing file.
 *
 * This function is meant to be used with UFCS, so that it can be placed
 * within option definition chain.
 *
 * Examples:
 * ---
 * new Program("test")
 *      .add(new Option("c", "config", "path to config file")
 *          .accpetsFiles()
 *      )
 * ---
 *
 * See_Also:
 *   FileSystemValidator, acceptsDirectories, acceptsPaths
 */
public T acceptsFiles(T: IEntry)(T entry) {
    return entry.validate(new FileSystemValidator(FileType.File));
}


/**
 * Helper function to require passing a path pointing to existing directory.
 *
 * This function is meant to be used with UFCS, so that it can be placed
 * within option definition chain.
 *
 * Examples:
 * ---
 * new Program("ls")
 *      .add(new Argument("directory", "directory to list")
 *          .acceptsDirectories()
 *      )
 * ---
 *
 * See_Also:
 *   FileSystemValidator, acceptsFiles, acceptsPaths
 */
public T acceptsDirectories(T: IEntry)(T entry) {
    return entry.validate(new FileSystemValidator(FileType.Directory));
}


/**
 * Helper function to require passing a path pointing to existing file or directory.
 *
 * This function is meant to be used with UFCS, so that it can be placed
 * within option definition chain.
 *
 * Params:
 *   existing - whenever path target must exist
 *
 * Examples:
 * ---
 * new Program("rm")
 *      .add(new Argument("target", "target to remove")
 *          .acceptsPaths(true)
 *      )
 * ---
 *
 * See_Also:
 *   FileSystemValidator, acceptsDirectories, acceptsFiles
 */
public T acceptsPaths(T: IEntry)(T entry, bool existing) {
    return entry.validate(new FileSystemValidator(existing));
}

/**
 * Validates input based on delegate.
 *
 * Delegate receives all arguments that `IValidator.validate` receives, that is
 * information about entry being checked and an array of values to perform check on.
 *
 * For less verbose usage, check `validateWith` and `validateEachWith` helper functions.
 *
 * Examples:
 * ---
 * new Program("rm")
 *      .add(new Argument("target", "target to remove")
 *          .validate(new DelegateValidator((entry, args) {
 *               foreach (arg; args) {
 *                   if (arg == "foo") throw new ValidationException("invalid number"); // would throw with "invalid number"
 *               }
 *          }))
 *          // or
 *          .validateEachWith((entry, arg) {
 *               if (arg == "5") throw new ValidationException("invalid number"); // would throw with "invalid number"
 *          })
 *          // or
 *          .validateEachWith(arg => isGood(arg), "must be good") // would throw with "flag a must be good"
 *      )
 * ---
 *
 * See_Also:
 *   validateWith, validateEachWith
 */
public class DelegateValidator : IValidator {
    /// Validator function type
    alias ValidatorFunc = void delegate(IEntry, string[]);

    /// Validator function
    ValidatorFunc validator;

    /// Creates instance of DelegateValidator
    public this(ValidatorFunc validator) nothrow pure @safe @nogc {
        this.validator = validator;
    }

    /// Validates input
    public void validate(IEntry entry, string[] args) {
        this.validator(entry, args);
    }
}

/**
 * Helper function to add custom validating delegate.
 *
 * This function is meant to be used with UFCS, so that it can be placed
 * within option definition chain.
 *
 * In contrast with `validateEachWith`, this functions makes a single call to delegate with all values.
 *
 * Params:
 *   validator - delegate performing validation of all values
 *
 * Examples:
 * ---
 * new Program("rm")
 *      .add(new Argument("target", "target to remove")
 *          .validateWith((entry, args) {
 *              foreach (arg; args) {
 *                  // do something
 *              }
 *          })
 *      )
 * ---
 *
 * See_Also:
 *   DelegateValidator, validateEachWith
 */
public T validateWith(T: IEntry)(T entry, DelegateValidator.ValidatorFunc validator) {
    return entry.validate(new DelegateValidator(validator));
}


/**
 * Helper function to add custom validating delegate.
 *
 * This function is meant to be used with UFCS, so that it can be placed
 * within option definition chain.
 *
 * In contrast with `validateWith`, this functions makes call to delegate for every value.
 *
 * Params:
 *   validator - delegate performing validation of single value
 *
 * Examples:
 * ---
 * new Program("rm")
 *      .add(new Argument("target", "target to remove")
 *          .validateEachWith((entry, arg) {
 *              // do something
 *          })
 *      )
 * ---
 *
 * See_Also:
 *   DelegateValidator, validateWith
 */
public T validateEachWith(T: IEntry)(T entry, void delegate(IEntry, string) validator) {
    return validateWith!T(entry, (e, args) { args.each!(a => validator(e, a)); });
}


/**
 * Helper function to add custom validating delegate.
 *
 * This function is meant to be used with UFCS, so that it can be placed
 * within option definition chain.
 *
 * This function automatically prepends entry information to your error message,
 * so that call to `new Option("", "foo", "").validateWith(a => a.isDir, "must be a directory")`
 * on failure would throw `ValidationException` with message `option foo must be a directory`.
 *
 * Params:
 *   validator - delegate performing validation, returning true on success
 *   message - error message
 *
 * Examples:
 * ---
 * new Program("rm")
 *      .add(new Argument("target", "target to remove")
 *          .validateEachWith(arg => arg.isSymLink, "must be a symlink")
 *      )
 * ---
 *
 * See_Also:
 *   DelegateValidator, validateWith
 */
public T validateEachWith(T: IEntry)(T entry, bool delegate(string) validator, string errorMessage) {
    return entry.validateEachWith((entry, arg) {
        if (!validator(arg)) {
            throw new ValidationException(null, "%s %s %s".format(entry.getEntryKindName(), entry.name, errorMessage));
        }
    });
}

// enum
unittest {
    import commandr.program;
    import commandr.option;
    import commandr.parser;
    import std.exception : assertThrown, assertNotThrown;

    assertNotThrown!ValidationException(
        new Program("test")
            .add(new Option("t", "type", "foo")
                .acceptsValues(["a", "b"])
            )
            .parseArgsNoRef(["test"])
    );

    assertNotThrown!ValidationException(
        new Program("test")
            .add(new Option("t", "type", "foo")
                .acceptsValues(["a", "b"])
            )
            .parseArgsNoRef(["test", "--type", "a"])
    );

    assertNotThrown!ValidationException(
        new Program("test")
            .add(new Option("t", "type", "foo")
                .acceptsValues(["a", "b"])
                .repeating
            )
            .parseArgsNoRef(["test", "--type", "a", "--type", "b"])
    );

    assertThrown!ValidationException(
        new Program("test")
            .add(new Option("t", "type", "foo")
                .acceptsValues(["a", "b"])
                .repeating
            )
            .parseArgsNoRef(["test", "--type", "c", "--type", "b"])
    );

    assertThrown!ValidationException(
        new Program("test")
            .add(new Option("t", "type", "foo")
                .acceptsValues(["a", "b"])
                .repeating
            )
            .parseArgsNoRef(["test", "--type", "a", "--type", "z"])
    );
}

// delegate
unittest {
    import commandr.program;
    import commandr.option;
    import commandr.parser;
    import std.exception : assertThrown, assertNotThrown;
    import std.string : isNumeric;

    assertNotThrown!ValidationException(
        new Program("test")
            .add(new Option("t", "type", "foo")
                .validateEachWith(a => isNumeric(a), "must be an integer")
            )
            .parseArgsNoRef(["test", "--type", "50"])
    );

    assertThrown!ValidationException(
        new Program("test")
            .add(new Option("t", "type", "foo")
                .validateEachWith(a => isNumeric(a), "must be an integer")
            )
            .parseArgsNoRef(["test", "--type", "a"])
    );
}
