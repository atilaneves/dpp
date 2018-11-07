module dpp.translation.exception;


/**
   Some C++ concepts simply have no D equivalent
 */
class UntranslatableException: Exception {
    import std.exception: basicExceptionCtors;

    mixin basicExceptionCtors;
}
